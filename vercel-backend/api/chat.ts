import type { VercelRequest, VercelResponse } from '@vercel/node';

interface ChatRequest {
  message: string;
  metrics?: string;
  conversationHistory?: Array<{role: string; content: string}>;
}

interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

interface OpenRouterResponse {
  id: string;
  model: string;
  choices: Array<{
    message: {
      role: string;
      content: string;
    };
    finish_reason: string;
  }>;
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { message, metrics, conversationHistory = [] } = req.body as ChatRequest;

    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const openrouterApiKey = process.env.OPENROUTER_API_KEY;
    if (!openrouterApiKey) {
      return res.status(500).json({ error: 'OpenRouter API key not configured' });
    }

    // Build system prompt with health metrics context
    const systemPrompt = `You are Babble, a friendly health insights assistant for the Matrix Health app.

The user is tracking their health metrics from Apple HealthKit. Your role is to:
- Analyze correlations between different health metrics across the timeframes the user asks about
- Provide actionable insights and suggestions based on trends and patterns
- Be conversational, encouraging, and concise
- Use simple language, avoid medical jargon
- When discussing metrics, reference specific numbers and trends
- Answer questions about any timeframe within the last 30 days

${metrics ? `\nUser's Health Metrics (last 30 days):\n${metrics}` : ''}

Keep responses brief (2-3 sentences) unless asked for detail.`;

    // Build messages array for OpenRouter (OpenAI-compatible format)
    const messages: ChatMessage[] = [
      {
        role: 'system' as const,
        content: systemPrompt
      },
      ...conversationHistory.map(msg => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content
      })),
      {
        role: 'user' as const,
        content: message
      }
    ];

    // Call OpenRouter API
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openrouterApiKey}`,
        'HTTP-Referer': 'https://github.com/matrix-health',
        'X-Title': 'Matrix Health - Babble',
      },
      body: JSON.stringify({
        model: 'anthropic/claude-3.5-sonnet',
        messages: messages,
        max_tokens: 1024,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('OpenRouter API error:', error);
      return res.status(response.status).json({
        error: 'Failed to get response from AI',
        details: error
      });
    }

    const data = await response.json() as OpenRouterResponse;
    const assistantMessage = data.choices[0]?.message?.content || 'Sorry, I could not generate a response.';

    return res.status(200).json({
      message: assistantMessage,
      usage: {
        input_tokens: data.usage.prompt_tokens,
        output_tokens: data.usage.completion_tokens,
      },
      model: data.model,
    });

  } catch (error) {
    console.error('Error in chat handler:', error);
    return res.status(500).json({
      error: 'Internal server error',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}
