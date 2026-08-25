import { useEffect } from 'react'
import { BrowserRouter } from 'react-router-dom'
import { AppRoutes } from './core/router/routes'
import { useAuthStore } from './core/auth/authStore'

export default function App() {
  const bootstrap = useAuthStore((s) => s.bootstrap)

  // Runs exactly once on app start — re-running would repeatedly hit
  // /auth/refresh for no reason. `bootstrap` is a stable Zustand action
  // reference, so it's intentionally left out of the dependency array.
  useEffect(() => {
    void bootstrap()
  }, [])

  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  )
}
