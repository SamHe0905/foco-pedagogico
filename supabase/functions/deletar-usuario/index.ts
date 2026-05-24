import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )

    // Extrai userId do JWT
    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace('Bearer ', '').trim()
    if (!token) return json({ error: 'Não autenticado.' }, 401)

    let callerId: string
    try {
      const payload = token.split('.')[1]
      const claims  = JSON.parse(atob(payload))
      callerId = claims.sub as string
    } catch {
      return json({ error: 'Token inválido.' }, 401)
    }

    // Verifica role de quem está deletando
    const { data: perfil } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', callerId)
      .single()

    const myRole = perfil?.role as string | undefined
    const autorizado =
      myRole === 'diretor' ||
      myRole === 'diretor-adjunto' ||
      myRole === 'coordenacao' ||
      myRole === 'supervisor'

    if (!autorizado) return json({ error: 'Sem permissão.' }, 403)

    // Lê o ID do usuário a ser deletado
    const { userId } = await req.json()
    if (!userId) return json({ error: 'userId é obrigatório.' }, 400)

    // Não permite deletar a si mesmo
    if (userId === callerId) {
      return json({ error: 'Você não pode excluir sua própria conta.' }, 400)
    }

    // Coordenador não pode deletar diretores
    if (myRole === 'coordenacao' || myRole === 'supervisor') {
      const { data: alvo } = await supabaseAdmin
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single()

      const roleAlvo = alvo?.role as string | undefined
      if (roleAlvo === 'diretor' || roleAlvo === 'diretor-adjunto') {
        return json({ error: 'Sem permissão para excluir este usuário.' }, 403)
      }
    }

    // Deleta o usuário do auth (cascade remove o profile)
    const { error: deleteErr } = await supabaseAdmin.auth.admin.deleteUser(userId)

    if (deleteErr) return json({ error: deleteErr.message }, 400)

    return json({ success: true })
  } catch (err) {
    console.error(err)
    return json({ error: String(err) }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
