import { useState, type FormEvent } from 'react'
import { useAuthStore } from '../../../core/auth/authStore'
import { Field, TextInput, PrimaryButton, ErrorText } from '../../../shared/components/FormPrimitives'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const login = useAuthStore((s) => s.login)
  const isBusy = useAuthStore((s) => s.isBusy)
  const errorMessage = useAuthStore((s) => s.errorMessage)

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    void login(email, password)
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-page px-4">
      <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-8 shadow-sm">
        <div className="mb-6 flex items-center gap-2">
          <span className="text-2xl">🏏</span>
          <h1 className="text-lg font-bold text-text-primary">CricLeague</h1>
        </div>
        <h2 className="mb-1 text-xl font-bold text-text-primary">Sign in</h2>
        <p className="mb-6 text-sm text-text-secondary">Admin dashboard</p>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <Field label="Email">
            <TextInput
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </Field>
          <Field label="Password">
            <TextInput
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>
          <ErrorText>{errorMessage}</ErrorText>
          <PrimaryButton type="submit" disabled={isBusy}>
            {isBusy ? 'Signing in…' : 'Sign in'}
          </PrimaryButton>
        </form>
      </div>
    </div>
  )
}
