import { signInWithOAuth } from "@/app/auth/actions"

export default function LoginPage() {
  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6">
      <div className="w-full max-w-sm flex flex-col gap-3">

        <div className="text-center mb-4">
          <h1 className="text-2xl font-bold">CollabMatch</h1>
          <p className="text-muted-foreground text-sm mt-1">
            Conectá tu red principal para continuar
          </p>
        </div>

        {/* Twitch */}
        <form action={signInWithOAuth.bind(null, "twitch")}>
          <button type="submit" className="w-full flex items-center gap-3 bg-[#9147ff] hover:bg-[#7d3ae0] text-white rounded-lg px-4 py-3 font-medium transition-colors">
            <span>📡</span> Continuar con Twitch
          </button>
        </form>

        {/* YouTube (Google OAuth) */}
        <form action={signInWithOAuth.bind(null, "google")}>
          <button type="submit" className="w-full flex items-center gap-3 bg-[#ff0033] hover:bg-[#cc0029] text-white rounded-lg px-4 py-3 font-medium transition-colors">
            <span>▶</span> Continuar con YouTube
          </button>
        </form>

        {/* GitHub - útil para desarrollo */}
        <form action={signInWithOAuth.bind(null, "github")}>
          <button type="submit" className="w-full flex items-center gap-3 bg-[#24292e] hover:bg-[#2f363d] text-white rounded-lg px-4 py-3 font-medium transition-colors">
            <span>🐙</span> Continuar con GitHub
          </button>
        </form>

      </div>
    </div>
  )
}