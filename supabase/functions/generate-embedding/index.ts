import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS preflight 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { input } = await req.json()

    if (!input || typeof input !== 'string') {
      throw new Error('Invalid input: expected a string')
    }

    // Supabase AI 임베딩 생성 (gte-small 모델, 384 차원)
    const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: input,
        dimensions: 384
      })
    })

    if (!embeddingResponse.ok) {
      const errorData = await embeddingResponse.text()
      console.error('OpenAI API error:', errorData)
      throw new Error(`OpenAI API error: ${embeddingResponse.status}`)
    }

    const embeddingData = await embeddingResponse.json()
    const embedding = embeddingData.data[0].embedding

    // 벡터 차원 검증
    if (!Array.isArray(embedding) || embedding.length !== 384) {
      throw new Error(`Invalid embedding dimension: expected 384, got ${embedding.length}`)
    }

    return new Response(
      JSON.stringify({ embedding }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error generating embedding:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
