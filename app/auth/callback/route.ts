import { createClient } from "@/lib/supabase/client"
import { NextResponse } from "next/server"

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get("code")
  const isLinking = searchParams.get("linking")

  if (code) {
    const supabase = await createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }

  // Si estaba vinculando una red, vuelve al perfil
  // Si era login nuevo, va al onboarding
  return NextResponse.redirect(
    isLinking ? `${origin}/profile` : `${origin}/onboarding`
  )
}