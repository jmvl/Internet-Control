export default {
  // OpenAI Configuration
  openai: {
    model: {
      provider: "openai",
      id: "gpt-5-turbo-16k",
      apiKey: process.env.OPENAI_API_KEY,
      baseURL: "https://api.openai.com/v1"
    }
  },

  // Anthropic Claude Configuration
  anthropic: {
    model: {
      provider: "anthropic",
      id: "claude-3-sonnet-20240229",
      apiKey: process.env.ANTHROPIC_API_KEY,
      baseURL: "https://api.anthropic.com"
    }
  },

  // Google Gemini Configuration
  google: {
    model: {
      provider: "google",
      id: "gemini-pro",
      apiKey: process.env.GOOGLE_API_KEY,
      baseURL: "https://generativelanguage.googleapis.com"
    }
  },

  // Volcengine Configuration
  volcengine: {
    model: {
      provider: "volcengine",
      id: "doubao-pro-4k",
      apiKey: process.env.VOLCENGINE_API_KEY,
      baseURL: "https://ark.cn-beijing.volces.com"
    }
  },

  // Default model configuration (change as needed)
  model: {
    provider: "openai",
    id: "gpt-4",
    apiKey: process.env.OPENAI_API_KEY,
    baseURL: "https://api.openai.com/v1"
  }
};