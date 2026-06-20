import { z } from "zod";

export const uuidSchema = z.string().uuid();

export const assistRequestSchema = z.object({
  session_id: uuidSchema,
  transcript_context: z.string().trim().min(1).max(30000),
  user_question: z.string().trim().max(2000).optional(),
  language: z.string().trim().min(2).max(16).default("tr")
});

export const createSessionSchema = z.object({
  title: z.string().trim().max(160).optional(),
  platform: z.enum(["zoom", "teams", "meet", "other"]).optional()
});

export const updateSessionSchema = z.object({
  ended_at: z.string().datetime().nullable().optional(),
  status: z.enum(["active", "ended", "discarded"]).optional(),
  summary: z.string().trim().max(20000).nullable().optional()
});

export const transcriptChunkSchema = z.object({
  speaker: z.enum(["user", "other"]),
  text: z.string().trim().min(1).max(12000),
  start_offset_ms: z.number().int().nonnegative().nullable().optional(),
  end_offset_ms: z.number().int().nonnegative().nullable().optional()
});

export const transcriptBatchSchema = z.object({
  chunks: z.array(transcriptChunkSchema).min(1).max(250)
});

