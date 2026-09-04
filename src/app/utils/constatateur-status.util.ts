import { Constatateur, StatutConstatateur } from '../models/constatateur.model';

/**
 * Au-dela de ce delai, la derniere position remontee est consideree obsolete
 * et le constatateur est marque "HORS LIGNE" quel que soit son statut declare.
 */
export const POSITION_STALE_MS = 5 * 60_000;

export type StatusTone = 'available' | 'mission' | 'unavailable' | 'offline';

export interface EffectiveStatus {
  label: string;
  tone: StatusTone;
  stale: boolean;
}

export function isPositionStale(timestampMs: number | null | undefined, nowMs: number = Date.now()): boolean {
  if (!timestampMs || Number.isNaN(timestampMs)) {
    return true;
  }
  return nowMs - timestampMs > POSITION_STALE_MS;
}

export function statusLabel(statut: StatutConstatateur | string): string {
  switch (statut) {
    case 'DISPONIBLE':
      return 'DISPONIBLE';
    case 'EN_MISSION':
      return 'EN MISSION';
    case 'INDISPONIBLE':
      return 'INDISPONIBLE';
    default:
      return String(statut ?? '').toUpperCase();
  }
}

export function statusTone(statut: StatutConstatateur | string): StatusTone {
  switch (statut) {
    case 'DISPONIBLE':
      return 'available';
    case 'EN_MISSION':
      return 'mission';
    case 'INDISPONIBLE':
    default:
      return 'unavailable';
  }
}

/**
 * Statut "effectif" affiche a l'utilisateur :
 * - si la derniere position est obsolete (ou absente), on bascule en HORS LIGNE,
 * - sinon on conserve le statut declare par l'agent.
 */
export function getEffectiveStatus(c: Constatateur, nowMs: number = Date.now()): EffectiveStatus {
  const ts = c.position_actuelle?.timestamp ?? null;
  const stale = isPositionStale(ts, nowMs);
  if (stale) {
    return { label: 'HORS LIGNE', tone: 'offline', stale: true };
  }
  return { label: statusLabel(c.infos.statut), tone: statusTone(c.infos.statut), stale: false };
}

/** Age relatif lisible ("il y a 12 min", "il y a 2 h", "il y a 3 j"). */
export function relativePositionAge(timestampMs: number | null | undefined, nowMs: number = Date.now()): string {
  if (!timestampMs || Number.isNaN(timestampMs)) {
    return 'inconnue';
  }
  const diff = nowMs - timestampMs;
  if (diff < 0) {
    return "a l'instant";
  }
  const sec = Math.round(diff / 1000);
  if (sec < 60) {
    return `il y a ${sec}s`;
  }
  const min = Math.round(sec / 60);
  if (min < 60) {
    return `il y a ${min} min`;
  }
  const h = Math.round(min / 60);
  if (h < 24) {
    return `il y a ${h} h`;
  }
  const d = Math.round(h / 24);
  return `il y a ${d} j`;
}
