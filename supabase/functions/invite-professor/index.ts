import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

const ROLES_COORDENADOR = ['professor', 'professor_aee', 'supervisor', 'coordenacao', 'pcsa']
const ROLES_DIRETOR     = ['professor', 'professor_aee', 'supervisor', 'coordenacao', 'pcsa', 'diretor', 'diretor-adjunto', 'secretaria']
const ROLES_VALIDOS     = new Set(ROLES_DIRETOR)

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

    // ── Extrai userId do JWT ─────────────────────────────────────────────────
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

    // ── Verifica role de quem está convidando ────────────────────────────────
    const { data: perfil } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', callerId)
      .single()

    const myRole        = perfil?.role as string | undefined
    const isDirector    = myRole === 'diretor' || myRole === 'diretor-adjunto' || myRole === 'secretaria'
    const isCoordenador = myRole === 'coordenacao' || myRole === 'supervisor' || myRole === 'pcsa'

    if (!isDirector && !isCoordenador) {
      return json({ error: 'Sem permissão.' }, 403)
    }

    // ── Lê body ──────────────────────────────────────────────────────────────
    const { email, nome, role } = await req.json()

    if (!email || !nome || !role) {
      return json({ error: 'email, nome e role são obrigatórios.' }, 400)
    }

    const roleNorm  = (role  as string).trim().toLowerCase()
    const emailNorm = (email as string).trim().toLowerCase()
    const nomeNorm  = (nome  as string).trim()

    if (!ROLES_VALIDOS.has(roleNorm)) {
      return json({ error: `Cargo inválido: ${roleNorm}` }, 400)
    }

    const rolesPermitidos = isDirector ? ROLES_DIRETOR : ROLES_COORDENADOR
    if (!rolesPermitidos.includes(roleNorm)) {
      return json({ error: 'Sem permissão para convidar este cargo.' }, 403)
    }

    // ── Cria usuário com email confirmado (sem senha ainda) ──────────────────
    const { data: createData, error: createErr } =
      await supabaseAdmin.auth.admin.createUser({
        email:         emailNorm,
        email_confirm: true,
        user_metadata: { nome: nomeNorm, role: roleNorm },
      })

    if (createErr) {
      const msg = createErr.message.toLowerCase()
      if (msg.includes('already') || msg.includes('exists')) {
        return json(
          { error: 'Este e-mail já está cadastrado. Exclua o usuário antes de reenviar o convite.' },
          400,
        )
      }
      return json({ error: createErr.message }, 400)
    }

    const newUser = createData.user

    // ── Garante profile com o cargo correto ──────────────────────────────────
    await supabaseAdmin
      .from('profiles')
      .upsert(
        { id: newUser.id, nome: nomeNorm, role: roleNorm },
        { onConflict: 'id' },
      )

    // ── Gera link de definição de senha (recovery — mais confiável que invite) ─
    const { data: linkData, error: linkErr } =
      await supabaseAdmin.auth.admin.generateLink({
        type:  'recovery',
        email: emailNorm,
        options: {
          redirectTo: 'https://foco-pedagogico.vercel.app/auth/callback',
        },
      })

    if (linkErr) {
      return json({ error: linkErr.message }, 400)
    }

    const inviteLink = linkData.properties.action_link

    // ── Envia e-mail via SendGrid API ────────────────────────────────────────
    const sgKey = Deno.env.get('SENDGRID_API_KEY') ?? ''

    const mailBody = {
      personalizations: [{ to: [{ email: emailNorm, name: nomeNorm }] }],
      from: { email: 'foco.pedagogico.ms@gmail.com', name: 'Foco Pedagógico' },
      subject: 'Seu convite para o Foco Pedagógico',
      content: [{
        type:  'text/html',
        value: `
          <div style="font-family:sans-serif;max-width:480px;margin:0 auto;">
            <h2 style="color:#1565C0;">Bem-vindo ao Foco Pedagógico!</h2>
            <p>Olá, <strong>${nomeNorm}</strong>!</p>
            <p>Você foi convidado(a) para acessar o sistema de gestão pedagógica escolar.</p>
            <p>Clique no botão abaixo para criar sua senha de acesso:</p>
            <p style="text-align:center;margin:32px 0;">
              <a href="${inviteLink}"
                 style="background-color:#1565C0;color:#fff;padding:14px 28px;
                        text-decoration:none;border-radius:6px;font-size:16px;">
                Criar minha senha
              </a>
            </p>
            <p style="color:#666;font-size:13px;">
              Este link expira em 24 horas.<br>
              Se você não esperava este convite, ignore este e-mail.
            </p>
          </div>
        `,
      }],
    }

    const sgRes = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${sgKey}`,
      },
      body: JSON.stringify(mailBody),
    })

    if (!sgRes.ok) {
      const errText = await sgRes.text()
      console.error('SendGrid error:', errText)
      return json({ error: `Erro ao enviar e-mail: ${errText}` }, 500)
    }

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
