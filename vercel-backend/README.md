# Matrix Health - Vercel Backend

Simple serverless backend for AI health chat using OpenRouter API.

## Setup

### 1. Install Vercel CLI

```bash
npm install -g vercel
```

### 2. Login to Vercel

```bash
vercel login
```

### 3. Get OpenRouter API Key

1. Go to https://openrouter.ai/
2. Sign up/login with your account
3. Go to Keys section (https://openrouter.ai/keys)
4. Create a new API key
5. Copy the key (starts with `sk-or-...`)
6. Add credits at https://openrouter.ai/credits (costs ~$0.01-0.02 per chat)

### 4. Deploy to Vercel

```bash
cd vercel-backend
vercel
```

During deployment, you'll be asked:
- Set up and deploy? **Yes**
- Which scope? **Select your account**
- Link to existing project? **No**
- Project name? **matrix-health-backend** (or your choice)
- Directory? **Just press Enter** (current directory)

### 5. Add OpenRouter API Key as Environment Variable

```bash
vercel env add OPENROUTER_API_KEY
```

When prompted:
- Enter the value: **Paste your OpenRouter API key**
- Which environments? **Production, Preview, Development** (select all)

### 6. Redeploy with Environment Variable

```bash
vercel --prod
```

### 7. Get Your API URL

After deployment, you'll see:
```
✅ Production: https://matrix-health-backend-xxxxx.vercel.app
```

Copy this URL! You'll need it in your iOS app.

## Test Your Backend

```bash
curl -X POST https://your-vercel-url.vercel.app/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "How are my health metrics looking?",
    "metrics": "Steps: 8,543\nHeart Rate: 72 bpm\nSleep: 7.5 hours"
  }'
```

You should get a response from Claude via OpenRouter!

## Cost

- **Vercel**: FREE (100k requests/month)
- **OpenRouter (Claude Sonnet 4)**: ~$0.015-0.02 per conversation
- **Total**: ~$0.75-1.00/month for 50 chats

## Why OpenRouter?

- **Single API** for multiple AI models (Claude, GPT-4, etc.)
- **Competitive pricing** - often same or better than direct APIs
- **Easy switching** between models without code changes
- **Usage tracking** and analytics in one place

## API Endpoint

**POST** `/api/chat`

Request body:
```json
{
  "message": "How did my sleep affect my workout?",
  "metrics": "Sleep: 7.5h, Workout: 45 min cardio, Heart Rate: 145 bpm avg",
  "conversationHistory": [
    {"role": "user", "content": "Previous message"},
    {"role": "assistant", "content": "Previous response"}
  ]
}
```

Response:
```json
{
  "message": "Your 7.5 hours of sleep provided good recovery for your 45-minute cardio session...",
  "usage": {
    "input_tokens": 234,
    "output_tokens": 156
  },
  "model": "claude-sonnet-4-20250514"
}
```

## Monitoring

View logs and analytics:
```bash
vercel logs https://your-vercel-url.vercel.app
```

Or visit: https://vercel.com/dashboard

## Updating

Make changes to `api/chat.ts`, then:
```bash
vercel --prod
```

Done! ✨
