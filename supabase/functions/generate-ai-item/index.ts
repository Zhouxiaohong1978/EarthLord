import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { OpenAI } from "npm:openai@4.73.0";

// CORS 头部
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 请求接口
interface GenerateItemRequest {
  poiName: string;
  poiType: string;
  dangerLevel: number;
  itemCount: number;
}

// 物品数据接口
interface ItemData {
  name: string;
  name_en: string;
  story: string;
  story_en: string;
  category: string;
  rarity: string;
}

// 响应接口
interface GenerateItemResponse {
  success: boolean;
  items?: ItemData[];
  error?: string;
  timestamp?: string;
}

// POI 类型的中文名称映射
const poiTypeNames: Record<string, string> = {
  supermarket: "超市",
  pharmacy: "药店",
  hospital: "医院",
  restaurant: "餐厅",
  gas_station: "加油站",
  warehouse: "仓库",
  residential: "住宅区",
  office: "办公楼",
  school: "学校",
  park: "公园",
};

// 根据 POI 类型获取推荐物品分类
function getRecommendedCategories(poiType: string): string[] {
  const categoryMap: Record<string, string[]> = {
    supermarket: ["food", "water", "material", "tool"],
    pharmacy: ["medical", "water", "material"],
    hospital: ["medical", "tool", "clothing"],
    restaurant: ["food", "water", "tool"],
    gas_station: ["tool", "material", "misc"],
    warehouse: ["material", "tool", "weapon", "misc"],
    residential: ["food", "water", "clothing", "misc"],
    office: ["material", "tool", "misc"],
    school: ["food", "material", "misc"],
    park: ["misc", "material"],
  };
  return categoryMap[poiType] || ["misc", "material"];
}

// 根据危险等级调整稀有度分布
function getRarityDistribution(dangerLevel: number): string {
  if (dangerLevel >= 4) {
    return "稀有度分布: 普通(20%), 优秀(30%), 稀有(30%), 史诗(15%), 传说(5%)";
  } else if (dangerLevel >= 3) {
    return "稀有度分布: 普通(30%), 优秀(35%), 稀有(25%), 史诗(10%), 传说(0%)";
  } else if (dangerLevel >= 2) {
    return "稀有度分布: 普通(40%), 优秀(35%), 稀有(20%), 史诗(5%), 传说(0%)";
  } else {
    return "稀有度分布: 普通(60%), 优秀(30%), 稀有(10%), 史诗(0%), 传说(0%)";
  }
}

Deno.serve(async (req: Request) => {
  // 处理 OPTIONS 请求 (CORS 预检)
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 解析请求体
    const { poiName, poiType, dangerLevel, itemCount }: GenerateItemRequest = await req.json();

    // 验证输入
    if (!poiName || !poiType || dangerLevel < 1 || dangerLevel > 5 || itemCount < 1) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "无效的请求参数",
        } as GenerateItemResponse),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 获取 API Key
    const apiKey = Deno.env.get("DASHSCOPE_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "服务配置错误：缺少 API Key",
        } as GenerateItemResponse),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 初始化 OpenAI 客户端（阿里云百炼兼容端点）
    const openai = new OpenAI({
      apiKey: apiKey,
      baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
    });

    // 获取推荐分类和稀有度分布
    const recommendedCategories = getRecommendedCategories(poiType);
    const rarityDistribution = getRarityDistribution(dangerLevel);
    const poiTypeName = poiTypeNames[poiType] || poiType;

    // 构建系统提示词
    const systemPrompt = `你是一个末日生存游戏的物品生成器。玩家正在搜刮一个 POI (兴趣点)，你需要为玩家生成有趣且符合情境的物品。

### 游戏背景
地球经历末日灾难，玩家需要探索废墟寻找生存物资。每个物品都有独特的名称和背景故事。

### 物品分类
- water: 一切可饮用的液体，包括饮用水（矿泉水/纯净水/凉白开）、碳酸饮料（可乐/雪碧）、果蔬汁、茶饮料、咖啡饮料、植物蛋白饮料（豆浆/椰汁）、乳制品（牛奶/酸奶）、功能饮料（运动饮料/能量饮料）、酒精饮料（啤酒/白酒）等
- food: 可直接食用的固体或半固体食品，如罐头食品、面包、饼干、方便面、糖果、零食、肉干、饼干等；**注意：容器（保温箱、储备罐、水桶等）不属于food，归入tool或misc**
- medical: 医疗用品，如药物、绷带、注射器、消毒液、急救包等
- material: 建筑和制作原料，如木材、石头、金属板、布料、绳子、玻璃等
- tool: 工具、设备和容器，如工具箱、保温箱、储备罐、手电筒、发电机、锁具、打火机等
- weapon: 武器和防具，如刀具、枪械、弓箭、盾牌等
- clothing: 衣物和个人穿戴，如衣服、鞋子、手套、帽子、背包等
- misc: 其他难以归类的杂项，如书籍、地图、钥匙扣、装饰品、文件等

### 稀有度等级
- common: 普通物品，随处可见
- uncommon: 优秀物品，稍微少见
- rare: 稀有物品，难得一见
- epic: 史诗物品，极为罕见
- legendary: 传说物品，可遇不可求

### 生成规则
1. **名称**：5-12 个汉字，必须是具体可携带的实物名称（如："生锈的军用水壶"）。**严禁使用地点名称、店铺名称或建筑名称作为物品名称**
2. **英文名称**：对应的英文名称，3-6个英文单词（如："Rusty Military Canteen"）
3. **故事**：15-50 个汉字，描述物品的状态、来源或特殊之处
4. **英文故事**：对应的英文背景故事，15-40个英文单词
5. **分类**：根据 POI 类型选择合适的分类
6. **稀有度**：根据危险等级调整分布
7. **真实性**：物品应符合 POI 环境，不要生成不合理的物品

### 输出格式
返回 JSON 数组，每个物品包含:
{
  "name": "物品中文名称",
  "name_en": "Item English Name",
  "story": "中文背景故事",
  "story_en": "English background story",
  "category": "分类代码",
  "rarity": "稀有度代码"
}`;

    // 构建用户提示词
    const userPrompt = `请为以下 POI 生成 ${itemCount} 件物品：

**POI 信息**
- 名称：${poiName}
- 类型：${poiTypeName}
- 危险等级：${dangerLevel}/5

**生成要求**
- 推荐分类：${recommendedCategories.join(", ")}
- ${rarityDistribution}

请直接返回 JSON 数组，不要包含任何其他文字。`;

    console.log("🤖 开始调用阿里云百炼 API");
    console.log(`POI: ${poiName} (${poiTypeName}), 危险等级: ${dangerLevel}, 物品数: ${itemCount}`);

    // 调用 AI API
    const completion = await openai.chat.completions.create({
      model: "qwen-flash",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.9,
      max_tokens: 1000,
    });

    // 解析 AI 响应
    const aiResponse = completion.choices[0]?.message?.content;
    if (!aiResponse) {
      throw new Error("AI 未返回内容");
    }

    console.log("✅ AI 响应成功");
    console.log("响应内容:", aiResponse.substring(0, 200));

    // 清理 JSON（移除可能的 markdown 代码块标记）
    let cleanedResponse = aiResponse.trim();
    if (cleanedResponse.startsWith("```json")) {
      cleanedResponse = cleanedResponse.replace(/^```json\s*/, "").replace(/\s*```$/, "");
    } else if (cleanedResponse.startsWith("```")) {
      cleanedResponse = cleanedResponse.replace(/^```\s*/, "").replace(/\s*```$/, "");
    }

    // 解析 JSON
    const items: ItemData[] = JSON.parse(cleanedResponse);

    // 验证物品数据
    if (!Array.isArray(items) || items.length === 0) {
      throw new Error("AI 返回的物品数据格式错误");
    }

    // 验证每个物品的字段，name_en/story_en 缺失时用中文补位
    for (const item of items) {
      if (!item.name || !item.story || !item.category || !item.rarity) {
        throw new Error("物品数据缺少必需字段");
      }
      // 防止 AI 把 POI 名称当物品名返回
      if (item.name === poiName || item.name.includes(poiName)) {
        throw new Error(`物品名称不能与POI名称相同: ${item.name}`);
      }
      if (!item.name_en) item.name_en = item.name;
      if (!item.story_en) item.story_en = item.story;
    }

    console.log(`✅ 成功生成 ${items.length} 件物品`);
    for (const item of items) {
      console.log(`  - [${item.rarity}] ${item.name}`);
    }

    // 返回成功响应
    return new Response(
      JSON.stringify({
        success: true,
        items: items,
        timestamp: new Date().toISOString(),
      } as GenerateItemResponse),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ AI 生成错误:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "未知错误",
        timestamp: new Date().toISOString(),
      } as GenerateItemResponse),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
