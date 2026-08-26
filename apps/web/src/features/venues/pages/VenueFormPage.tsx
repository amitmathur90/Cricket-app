import { useState, type ChangeEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuthStore } from '../../../core/auth/authStore'
import { resolveMediaUrl, uploadFile } from '../../../core/api/client'
import { Field, TextInput, Textarea, SelectInput, PrimaryButton, SecondaryButton, ErrorText } from '../../../shared/components/FormPrimitives'
import { useVenue } from '../hooks/useVenues'
import { useCreateVenue } from '../hooks/useCreateVenue'
import { useUpdateVenue } from '../hooks/useUpdateVenue'
import type { CreateVenuePayload, Venue, VenueStatus } from '../../../types/venue'

function emptyToUndefined(text: string): string | undefined {
  const trimmed = text.trim()
  return trimmed === '' ? undefined : trimmed
}

/**
 * Outer data-fetching shell — waits for the existing venue (edit mode) to
 * load, then hands it to `VenueFormFields` keyed by the venue id, so that
 * component's state can be initialized directly from props (a `useState`
 * initializer) instead of copied in via a `useEffect`, which would trip
 * react/set-state-in-effect for no benefit here (same shape MatchFormPage
 * uses for its own create/edit split).
 */
export function VenueFormPage() {
  const { venueId } = useParams<{ venueId: string }>()
  const isEditing = !!venueId

  const { data: existingVenue, isLoading: isLoadingVenue } = useVenue(venueId)

  if (isEditing && isLoadingVenue) {
    return <div className="text-sm text-text-secondary">Loading venue…</div>
  }

  return <VenueFormFields key={existingVenue?.id ?? 'new'} venueId={venueId} existing={existingVenue ?? null} />
}

/**
 * Single form covering both create and edit — venues are a lightweight
 * identity record (name/location/capacity/pitch/facilities/photo/status),
 * not a multi-step registration, so this deliberately isn't a wizard like
 * TournamentCreatePage (mirrors VenueFormDialog's "one form, `existing`
 * decides create-vs-edit" framing from the mobile app, just as a full page
 * instead of a modal dialog since this app has no shared dialog component).
 * Route shapes this expects to be wired: `/venues/create` and
 * `/venues/:venueId/edit`.
 */
function VenueFormFields({ venueId, existing }: { venueId: string | undefined; existing: Venue | null }) {
  const isEditing = !!venueId
  const navigate = useNavigate()
  const organizationId = useAuthStore((s) => s.activeOrgId)

  const createMutation = useCreateVenue()
  const updateMutation = useUpdateVenue()
  const submitting = createMutation.isPending || updateMutation.isPending

  const [name, setName] = useState(existing?.name ?? '')
  const [location, setLocation] = useState(existing?.location ?? '')
  const [capacity, setCapacity] = useState(existing?.capacity != null ? String(existing.capacity) : '')
  const [pitchType, setPitchType] = useState(existing?.pitchType ?? '')
  const [facilities, setFacilities] = useState(existing?.facilities ?? '')
  const [photoUrl, setPhotoUrl] = useState<string | null>(existing?.photoUrl ?? null)
  const [status, setStatus] = useState<VenueStatus>(existing?.status ?? 'active')
  const [uploadingPhoto, setUploadingPhoto] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  async function handlePhotoChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file || !organizationId) return
    setUploadingPhoto(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const { data } = await uploadFile(`/organizations/${organizationId}/uploads`, formData)
      setPhotoUrl((data as { url: string }).url)
    } catch {
      setFormError('Could not upload photo. You can continue without one.')
    } finally {
      setUploadingPhoto(false)
    }
  }

  async function handleSubmit() {
    if (!name.trim()) {
      setFormError('Venue name is required')
      return
    }
    const capacityText = capacity.trim()
    const parsedCapacity = capacityText === '' ? undefined : Number.parseInt(capacityText, 10)
    if (capacityText && (parsedCapacity === undefined || Number.isNaN(parsedCapacity) || parsedCapacity < 0)) {
      setFormError('Capacity must be a non-negative whole number')
      return
    }
    if (!organizationId) return

    setFormError(null)
    const payload: CreateVenuePayload = {
      name: name.trim(),
      location: emptyToUndefined(location),
      capacity: parsedCapacity,
      pitchType: emptyToUndefined(pitchType),
      facilities: emptyToUndefined(facilities),
      photoUrl: photoUrl ?? undefined,
      status,
    }

    try {
      if (isEditing && venueId) {
        await updateMutation.mutateAsync({ venueId, payload })
        navigate(`/venues/${venueId}`)
      } else {
        const created = await createMutation.mutateAsync(payload)
        navigate(`/venues/${created.id}`)
      }
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Could not save venue')
    }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <Link
        to={isEditing && venueId ? `/venues/${venueId}` : '/venues'}
        className="text-xs font-medium text-text-secondary hover:text-primary"
      >
        ← {isEditing ? 'Venue' : 'Venues'}
      </Link>

      <h1 className="mt-2 text-2xl font-bold text-text-primary">{isEditing ? 'Edit venue' : 'Create venue'}</h1>

      <div className="mt-6 flex flex-col gap-4 rounded-2xl border border-border bg-card p-6">
        <Field label="Venue name *">
          <TextInput required value={name} onChange={(e) => setName(e.target.value)} />
        </Field>

        <Field label="Photo (optional)">
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg">
              {uploadingPhoto ? '…' : photoUrl ? (
                <img src={resolveMediaUrl(photoUrl)} alt="" className="h-full w-full object-cover" />
              ) : (
                '📍'
              )}
            </div>
            <label className="cursor-pointer rounded-xl border border-border bg-page px-3.5 py-2 text-sm font-medium text-text-secondary hover:bg-border/30">
              {photoUrl ? 'Change photo' : 'Upload photo'}
              <input type="file" accept="image/*" className="hidden" onChange={handlePhotoChange} disabled={uploadingPhoto} />
            </label>
          </div>
        </Field>

        <Field label="Location (optional)">
          <TextInput value={location} onChange={(e) => setLocation(e.target.value)} />
        </Field>

        <div className="grid grid-cols-2 gap-4">
          <Field label="Capacity (optional)">
            <TextInput type="number" min={0} value={capacity} onChange={(e) => setCapacity(e.target.value)} />
          </Field>
          <Field label="Pitch type (optional)">
            <TextInput placeholder="e.g. Turf, Grass, Matting" value={pitchType} onChange={(e) => setPitchType(e.target.value)} />
          </Field>
        </div>

        <Field label="Facilities (optional)">
          <Textarea
            rows={2}
            placeholder="e.g. Parking, Floodlights, Pavilion"
            value={facilities}
            onChange={(e) => setFacilities(e.target.value)}
          />
        </Field>

        {isEditing && (
          <Field label="Status">
            <SelectInput value={status} onChange={(e) => setStatus(e.target.value as VenueStatus)}>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </SelectInput>
          </Field>
        )}

        <ErrorText>{formError}</ErrorText>

        <div className="mt-2 flex justify-end gap-2">
          <SecondaryButton
            type="button"
            className="w-auto"
            onClick={() => navigate(isEditing && venueId ? `/venues/${venueId}` : '/venues')}
            disabled={submitting}
          >
            Cancel
          </SecondaryButton>
          <PrimaryButton type="button" className="w-auto" onClick={handleSubmit} disabled={submitting || uploadingPhoto}>
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Create venue'}
          </PrimaryButton>
        </div>
      </div>
    </div>
  )
}
