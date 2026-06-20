import OpenAI from "openai";

let openAIClient: OpenAI | null = null;

export function requiredEnv(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

export function getOpenAI(): OpenAI {
  if (!openAIClient) {
    openAIClient = new OpenAI({
      apiKey: requiredEnv("OPENAI_API_KEY")
    });
  }

  return openAIClient;
}

