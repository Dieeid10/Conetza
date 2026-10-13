"use server"

import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { Provider } from "@supabase/supabase-js"

export async function signInWithOAuth(provider: Provider) {
  const supabase = await createClient()

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider,
    options: {
      redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`,
      // Los scopes los defines por provider
      scopes: getScopes(provider),
    },
  })

  if (error) redirect("/auth/error")
  if (data.url) redirect(data.url)
}

// Cada provider necesita distintos permisos
function getScopes(provider: Provider): string {
  const scopes: Partial<Record<Provider, string>> = {
    github:   "read:user user:email",
    google:   "openid email profile https://www.googleapis.com/auth/youtube.readonly",
    twitch:   "user:read:email user:read:follows",
  }
  return scopes[provider] ?? ""
}

export async function linkPlatform(provider: Provider) {
  const supabase = await createClient()

  const { data, error } = await supabase.auth.linkIdentity({
    provider,
    options: {
      redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback?linking=true`,
      scopes: getScopes(provider),
    },
  })

  if (error) redirect("/auth/error")
  if (data.url) redirect(data.url)
}