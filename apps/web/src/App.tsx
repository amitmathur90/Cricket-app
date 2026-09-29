import { useEffect } from 'react'
import { BrowserRouter } from 'react-router-dom'
import { AppRoutes } from './core/router/routes'
import { useAuthStore } from './core/auth/authStore'
import { warmUpBackend } from './core/api/client'

export default function App() {
  const bootstrap = useAuthStore((s) => s.bootstrap)

  // Runs exactly once on app start — re-running would repeatedly hit
  // /auth/refresh for no reason. `bootstrap` is a stable Zustand action
  // reference, so it's intentionally left out of the dependency array.
  useEffect(() => {
    // Unconditional, independent of bootstrap()/auth state — see
    // warmUpBackend's doc comment for why (a logged-out visit never
    // touches the network otherwise, so a cold Render backend would only
    // start waking up once the user submits the login form).
    warmUpBackend()
    void bootstrap()
  }, [])

  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  )
}
