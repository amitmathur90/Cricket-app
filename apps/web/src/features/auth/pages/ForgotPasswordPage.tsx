import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { authApi } from '../api/authApi'
import { Field, TextInput, PrimaryButton, ErrorText } from '../../../shared/components/FormPrimitives'

type Step = 'identifier' | 'otp' | 'newPassword' | 'success'

/** The full "Forgot password" wizard in one page (same "one route, an
 * internal step index" pattern as the mobile app's ForgotPasswordScreen) —
 * Step 1 (email/phone) -> Step 2 (6-digit OTP, emailed by MailService) ->
 * Step 3 (new password) -> success, mirroring AuthController's
 * forgot-password/verify-otp/reset-password endpoints one-to-one. Kept
 * self-contained (local state only) rather than routed through authStore,
 * since none of these three calls change the signed-in session. */
export function ForgotPasswordPage() {
  const navigate = useNavigate()
  const [step, setStep] = useState<Step>('identifier')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [identifier, setIdentifier] = useState('')
  const [otp, setOtp] = useState('')
  const [resetToken, setResetToken] = useState<string | null>(null)
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')

  async function handleIdentifierSubmit(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await authApi.requestPasswordReset(identifier.trim())
      setStep('otp')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send the code')
    } finally {
      setBusy(false)
    }
  }

  async function handleResend() {
    setBusy(true)
    setError(null)
    try {
      await authApi.requestPasswordReset(identifier.trim())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not resend the code')
    } finally {
      setBusy(false)
    }
  }

  async function handleOtpSubmit(event: FormEvent) {
    event.preventDefault()
    if (otp.trim().length !== 6) {
      setError('Enter the 6-digit code')
      return
    }
    setBusy(true)
    setError(null)
    try {
      const token = await authApi.verifyPasswordResetOtp(identifier.trim(), otp.trim())
      setResetToken(token)
      setStep('newPassword')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid or expired code')
    } finally {
      setBusy(false)
    }
  }

  async function handleNewPasswordSubmit(event: FormEvent) {
    event.preventDefault()
    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters')
      return
    }
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match')
      return
    }
    if (!resetToken) return
    setBusy(true)
    setError(null)
    try {
      await authApi.resetPassword(resetToken, newPassword)
      setStep('success')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not reset password')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-page px-4">
      <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-8 shadow-sm">
        <div className="mb-6 flex items-center gap-2">
          <span className="text-2xl">🏏</span>
          <h1 className="text-lg font-bold text-text-primary">CricLeague</h1>
        </div>

        {step === 'identifier' && (
          <>
            <h2 className="mb-1 text-xl font-bold text-text-primary">Forgot password</h2>
            <p className="mb-6 text-sm text-text-secondary">
              Enter your registered email or mobile number
            </p>
            <form onSubmit={handleIdentifierSubmit} className="flex flex-col gap-4">
              <Field label="Email / Mobile">
                <TextInput
                  required
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                />
              </Field>
              <ErrorText>{error}</ErrorText>
              <PrimaryButton type="submit" disabled={busy}>
                {busy ? 'Sending…' : 'Continue'}
              </PrimaryButton>
            </form>
          </>
        )}

        {step === 'otp' && (
          <>
            <h2 className="mb-1 text-xl font-bold text-text-primary">Verify your identity</h2>
            <p className="mb-6 text-sm text-text-secondary">
              Enter the 6-digit code sent to your email
            </p>
            <form onSubmit={handleOtpSubmit} className="flex flex-col gap-4">
              <Field label="6-digit code">
                <TextInput
                  required
                  inputMode="numeric"
                  maxLength={6}
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  className="text-center text-lg tracking-[0.5em]"
                />
              </Field>
              <ErrorText>{error}</ErrorText>
              <PrimaryButton type="submit" disabled={busy}>
                {busy ? 'Verifying…' : 'Verify OTP'}
              </PrimaryButton>
              <button
                type="button"
                onClick={handleResend}
                disabled={busy}
                className="text-sm font-medium text-primary hover:underline disabled:opacity-60"
              >
                Didn&apos;t get a code? Resend
              </button>
            </form>
          </>
        )}

        {step === 'newPassword' && (
          <>
            <h2 className="mb-6 text-xl font-bold text-text-primary">Create new password</h2>
            <form onSubmit={handleNewPasswordSubmit} className="flex flex-col gap-4">
              <Field label="New password">
                <TextInput
                  type="password"
                  required
                  autoComplete="new-password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                />
              </Field>
              <Field label="Confirm password">
                <TextInput
                  type="password"
                  required
                  autoComplete="new-password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                />
              </Field>
              <ErrorText>{error}</ErrorText>
              <PrimaryButton type="submit" disabled={busy}>
                {busy ? 'Resetting…' : 'Reset password'}
              </PrimaryButton>
            </form>
          </>
        )}

        {step === 'success' && (
          <div className="flex flex-col items-center gap-3 text-center">
            <span className="text-4xl">✅</span>
            <h2 className="text-xl font-bold text-text-primary">Password reset successfully</h2>
            <p className="text-sm text-text-secondary">Your password has been updated.</p>
            <PrimaryButton className="mt-3" onClick={() => navigate('/login')}>
              Go to login
            </PrimaryButton>
          </div>
        )}

        {step !== 'success' && (
          <p className="mt-6 text-center text-sm text-text-secondary">
            <Link to="/login" className="font-medium text-primary hover:underline">
              Back to sign in
            </Link>
          </p>
        )}
      </div>
    </div>
  )
}
