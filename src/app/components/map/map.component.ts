import { CommonModule } from '@angular/common';
import { AfterViewInit, Component, EventEmitter, Input, OnChanges, OnDestroy, Output, SimpleChanges, signal } from '@angular/core';
import * as L from 'leaflet';
import { Constatateur } from '../../models/constatateur.model';
import { getEffectiveStatus, StatusTone } from '../../utils/constatateur-status.util';

/** Réponse minimale Nominatim (search JSON). */
interface NominatimHit {
  lat: string;
  lon: string;
  display_name: string;
  type?: string;
}

interface DistanceModalData {
  addressLabel: string;
  distances: Array<{
    uid: string;
    agentName: string;
    color: string;
    distanceMeters: number;
    statusLabel: string;
    statusTone: StatusTone;
  }>;
}

interface MarkerLegendItem {
  uid: string;
  agentName: string;
  color: string;
  hasPosition: boolean;
}

@Component({
  selector: 'app-map',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './map.component.html',
  styleUrl: './map.component.scss'
})
export class MapComponent implements AfterViewInit, OnChanges, OnDestroy {
  @Input() constatateurs: Constatateur[] = [];
  @Input() selectedId: string | null = null;
  @Output() selectedIdChange = new EventEmitter<string>();
  @Output() mapReady = new EventEmitter<L.Map>();

  readonly addressQuery = signal('');
  readonly geocodeError = signal<string | null>(null);
  readonly isGeocoding = signal(false);
  readonly hasGeocodePin = signal(false);
  readonly distanceModalOpen = signal(false);
  readonly distanceModalData = signal<DistanceModalData | null>(null);

  private map: L.Map | null = null;
  private geocodeMarker: L.Marker | null = null;
  private readonly markers = new Map<string, L.Marker>();
  private readonly markerHoverCloseTimers = new Map<L.Marker, ReturnType<typeof setTimeout>>();
  private readonly lastLatLng = new Map<string, L.LatLngTuple>();
  private readonly defaultCenter: L.LatLngTuple = [33.5731, -7.5898];

  ngAfterViewInit(): void {
    this.map = L.map('tracking-map', {
      center: this.defaultCenter,
      zoom: 12,
      zoomControl: false
    });

    L.control.zoom({ position: 'bottomright' }).addTo(this.map);
    // Fond de carte "plan / rues" (léger et lisible).
    L.tileLayer(
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors'
      }
    ).addTo(this.map);

    this.mapReady.emit(this.map);
    this.syncMarkers();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (!this.map) {
      return;
    }
    if (changes['constatateurs']) {
      this.syncMarkers();
    }
    if (changes['selectedId']) {
      this.focusSelectedMarker();
    }
  }

  ngOnDestroy(): void {
    this.clearGeocodeResult();
    this.markers.forEach((m) => {
      this.clearMarkerHoverTimer(m);
      m.remove();
    });
    this.markers.clear();
    this.map?.remove();
    this.map = null;
  }

  onAddressInput(ev: Event): void {
    const el = ev.target as HTMLInputElement;
    this.addressQuery.set(el.value);
    this.geocodeError.set(null);
  }

  /** Entrée dans le champ : pas de navigation, uniquement géocodage SPA. */
  onAddressSearchEnter(ev: Event): void {
    const ke = ev as KeyboardEvent;
    if (ke.key !== 'Enter') {
      return;
    }
    ke.preventDefault();
    void this.runAddressSearch();
  }

  runAddressSearchFromUi(): void {
    void this.runAddressSearch();
  }

  clearGeocodeResult(): void {
    if (this.geocodeMarker && this.map) {
      this.map.removeLayer(this.geocodeMarker);
    }
    this.geocodeMarker = null;
    this.hasGeocodePin.set(false);
  }

  closeDistanceModal(): void {
    this.distanceModalOpen.set(false);
  }

  /**
   * Géocodage Nominatim (OSM). Les navigateurs n’autorisent en général pas un User-Agent
   * personnalisé sur fetch : l’UA par défaut du navigateur est envoyé (conforme usage léger).
   */
  private async runAddressSearch(): Promise<void> {
    const q = this.addressQuery().trim();
    this.geocodeError.set(null);
    if (!q) {
      this.geocodeError.set('Saisissez une adresse ou un lieu.');
      return;
    }
    if (!this.map) {
      return;
    }

    this.clearGeocodeResult();
    this.isGeocoding.set(true);
    try {
      const params = new URLSearchParams({
        q,
        format: 'json',
        limit: '1',
        countrycodes: 'ma',
        addressdetails: '1'
      });
      const url = `https://nominatim.openstreetmap.org/search?${params.toString()}`;
      const res = await fetch(url, {
        method: 'GET',
        headers: {
          Accept: 'application/json',
          'Accept-Language': 'fr'
        }
      });
      if (!res.ok) {
        this.geocodeError.set('Service de recherche indisponible. Réessayez plus tard.');
        return;
      }
      const raw = await res.json();
      const data = Array.isArray(raw) ? raw : [];
      const hit = data[0] as NominatimHit | undefined;
      const lat = hit ? parseFloat(hit.lat) : NaN;
      const lon = hit ? parseFloat(hit.lon) : NaN;
      if (!hit || Number.isNaN(lat) || Number.isNaN(lon)) {
        this.geocodeError.set('Adresse non trouvée : aucun résultat au Maroc pour cette recherche.');
        return;
      }

      const latLng: L.LatLngTuple = [lat, lon];
      this.geocodeMarker = L.marker(latLng, { icon: this.createGeocodeSymbolIcon(), zIndexOffset: 500 })
        .bindPopup(`<div class="popup"><strong>Adresse</strong><br/>${this.escapeHtml(hit.display_name)}</div>`, {
          className: 'geocode-popup'
        })
        .bindTooltip('LIEU D\'ACCIDENT', {
          permanent: true,
          direction: 'top',
          offset: [0, -28],
          className: 'accident-place-badge'
        })
        .addTo(this.map);
      this.hasGeocodePin.set(true);
      const zoom = hit.type === 'house' || hit.type === 'building' || hit.type === 'shop' ? 17 : 16;
      this.map.setView(latLng, zoom, { animate: true });
      this.openDistanceModalForResult(latLng, hit.display_name);
    } catch {
      this.geocodeError.set('Impossible de contacter le service de géocodage.');
    } finally {
      this.isGeocoding.set(false);
    }
  }

  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  private openDistanceModalForResult(resultLatLng: L.LatLngTuple, addressLabel: string): void {
    if (!this.map) {
      return;
    }

    const resultPoint = L.latLng(resultLatLng[0], resultLatLng[1]);
    const distances = this.constatateurs
      .filter((c) => !!c.position_actuelle)
      .map((c) => {
        const point = L.latLng(c.position_actuelle!.latitude, c.position_actuelle!.longitude);
        const distanceMeters = this.map!.distance(resultPoint, point);
        const status = getEffectiveStatus(c);
        return {
          uid: c.uid,
          agentName: c.infos.nom,
          color: this.agentColor(c.uid),
          distanceMeters,
          statusLabel: status.label,
          statusTone: status.tone
        };
      })
      .sort((a, b) => a.distanceMeters - b.distanceMeters);

    if (distances.length === 0) {
      this.geocodeError.set('Aucune position de constatateur disponible pour calculer la distance.');
      this.distanceModalOpen.set(false);
      return;
    }

    this.distanceModalData.set({
      addressLabel,
      distances
    });
    this.distanceModalOpen.set(true);
  }

  formatDistance(distanceMeters: number): string {
    if (distanceMeters >= 1000) {
      return `${(distanceMeters / 1000).toFixed(2)} km`;
    }
    return `${Math.round(distanceMeters)} m`;
  }

  compactAddressLabel(label: string, maxLen = 72): string {
    const clean = (label ?? '').trim();
    if (clean.length <= maxLen) {
      return clean;
    }
    return `${clean.slice(0, Math.max(0, maxLen - 1)).trimEnd()}...`;
  }

  markerLegend(): MarkerLegendItem[] {
    return this.constatateurs
      .map((c) => ({
        uid: c.uid,
        agentName: c.infos.nom,
        color: this.agentColor(c.uid),
        hasPosition: !!c.position_actuelle
      }))
      .sort((a, b) => a.agentName.localeCompare(b.agentName, 'fr', { sensitivity: 'base' }));
  }

  /** Symbole cible (repère) — distinct des marqueurs constatateurs, sans rechargement SPA. */
  private createGeocodeSymbolIcon(): L.DivIcon {
    const svg = `
      <svg width="68" height="68" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <circle cx="18" cy="18" r="15" fill="#ff4d6d" fill-opacity="0.18" stroke="#e11d48" stroke-width="2"/>
        <g transform="rotate(-18 18 18)">
          <path d="M8.5 19.5h19v3.2c0 .9-.7 1.6-1.6 1.6H10.1c-.9 0-1.6-.7-1.6-1.6z" fill="#dc2626" stroke="#7f1d1d" stroke-width="1.1"/>
          <path d="M11 19.5l3-4.7c.4-.6 1-.9 1.7-.9h5.6c.7 0 1.3.3 1.7.9l3 4.7z" fill="#ef4444" stroke="#7f1d1d" stroke-width="1.1"/>
          <path d="M14 15.2h8l1.7 3h-11.4z" fill="#93c5fd" stroke="#1e3a8a" stroke-width=".8"/>
          <rect x="17.55" y="15.2" width=".9" height="3" fill="#1e3a8a"/>
          <circle cx="12.2" cy="24.2" r="2.25" fill="#111827"/>
          <circle cx="23.8" cy="24.2" r="2.25" fill="#111827"/>
          <circle cx="12.2" cy="24.2" r="1.05" fill="#9ca3af"/>
          <circle cx="23.8" cy="24.2" r="1.05" fill="#9ca3af"/>
          <rect x="8.5" y="20.2" width="1.6" height="1" rx=".3" fill="#fde68a"/>
          <rect x="25.9" y="20.2" width="1.6" height="1" rx=".3" fill="#fca5a5"/>
        </g>
        <path d="M27 9l3-2M27 13l4 0M26 11l3 2" stroke="#facc15" stroke-width="1.6" stroke-linecap="round"/>
      </svg>
    `;
    return L.divIcon({
      className: 'geocode-marker',
      html: svg,
      iconSize: [68, 68],
      iconAnchor: [34, 34],
      popupAnchor: [0, -32]
    });
  }

  private syncMarkers(): void {
    if (!this.map) {
      return;
    }

    const currentIds = new Set(this.constatateurs.map((c) => c.uid));
    this.markers.forEach((marker, uid) => {
      if (!currentIds.has(uid)) {
        this.clearMarkerHoverTimer(marker);
        marker.remove();
        this.markers.delete(uid);
        this.lastLatLng.delete(uid);
      }
    });

    for (const constatateur of this.constatateurs) {
      const hasPosition = !!constatateur.position_actuelle;
      const isOffline = getEffectiveStatus(constatateur).tone === 'offline';
      const latLng: L.LatLngTuple = hasPosition
        ? [constatateur.position_actuelle!.latitude, constatateur.position_actuelle!.longitude]
        : this.lastLatLng.get(constatateur.uid) ?? this.defaultCenter;

      const icon = this.createMarkerIcon(constatateur.uid, hasPosition, isOffline);
      const existing = this.markers.get(constatateur.uid);
      if (!existing) {
        const marker = L.marker(latLng, {
          icon
        })
          .on('click', () => this.selectedIdChange.emit(constatateur.uid))
          .addTo(this.map);

        marker.bindPopup(this.popupContent(constatateur), { className: 'agent-popup' });
        marker.bindTooltip(this.agentTooltipContent(constatateur.uid, constatateur.infos.nom, hasPosition, isOffline), {
          permanent: true,
          direction: 'top',
          offset: [0, -14],
          className: 'agent-name-badge'
        });
        this.bindMarkerHoverPopup(marker);
        if (!hasPosition || isOffline) {
          marker.setOpacity(isOffline ? 0.85 : 0.65);
        }
        this.markers.set(constatateur.uid, marker);
      } else {
        existing.setIcon(icon);
        existing.setPopupContent(this.popupContent(constatateur));
        existing.setTooltipContent(this.agentTooltipContent(constatateur.uid, constatateur.infos.nom, hasPosition, isOffline));
        existing.setOpacity(!hasPosition ? 0.65 : isOffline ? 0.85 : 1);
        this.animateMarker(constatateur.uid, existing, latLng);
      }

      this.lastLatLng.set(constatateur.uid, latLng);
    }

    if (this.selectedId) {
      this.focusSelectedMarker();
      return;
    }

    this.fitAllConstatateursInView();
  }

  private fitAllConstatateursInView(): void {
    if (!this.map) {
      return;
    }

    const positioned = this.constatateurs
      .filter((c) => !!c.position_actuelle)
      .map((c) => [c.position_actuelle!.latitude, c.position_actuelle!.longitude] as L.LatLngTuple);

    if (positioned.length === 0) {
      this.map.setView(this.defaultCenter, 12, { animate: true });
      return;
    }

    if (positioned.length === 1) {
      this.map.setView(positioned[0], 14, { animate: true });
      return;
    }

    this.map.fitBounds(L.latLngBounds(positioned), { padding: [40, 40], maxZoom: 15, animate: true });
  }

  private focusSelectedMarker(): void {
    if (!this.map || !this.selectedId) {
      return;
    }
    const marker = this.markers.get(this.selectedId);
    if (!marker) {
      return;
    }
    marker.openPopup();
    this.map.panTo(marker.getLatLng(), { animate: true, duration: 0.5 });
  }

  private clearMarkerHoverTimer(marker: L.Marker): void {
    const t = this.markerHoverCloseTimers.get(marker);
    if (t !== undefined) {
      clearTimeout(t);
      this.markerHoverCloseTimers.delete(marker);
    }
  }

  private scheduleMarkerPopupClose(marker: L.Marker, delayMs: number): void {
    this.clearMarkerHoverTimer(marker);
    const id = setTimeout(() => {
      this.markerHoverCloseTimers.delete(marker);
      marker.closePopup();
    }, delayMs);
    this.markerHoverCloseTimers.set(marker, id);
  }

  private bindMarkerHoverPopup(marker: L.Marker): void {
    marker.on('mouseover', () => {
      this.clearMarkerHoverTimer(marker);
      marker.openPopup();
    });
    marker.on('mouseout', () => {
      this.scheduleMarkerPopupClose(marker, 200);
    });
    marker.on('popupopen', () => {
      const el = marker.getPopup()?.getElement();
      if (!el) {
        return;
      }
      const cancelScheduledClose = () => this.clearMarkerHoverTimer(marker);
      const onLeavePopup = () => this.scheduleMarkerPopupClose(marker, 120);
      el.addEventListener('mouseenter', cancelScheduledClose);
      el.addEventListener('mouseleave', onLeavePopup);
      marker.once('popupclose', () => {
        el.removeEventListener('mouseenter', cancelScheduledClose);
        el.removeEventListener('mouseleave', onLeavePopup);
      });
    });
  }

  private animateMarker(uid: string, marker: L.Marker, to: L.LatLngTuple): void {
    const from = this.lastLatLng.get(uid);
    if (!from || (from[0] === to[0] && from[1] === to[1])) {
      marker.setLatLng(to);
      return;
    }

    const start = performance.now();
    const duration = 450;
    const step = (time: number) => {
      const t = Math.min((time - start) / duration, 1);
      const lat = from[0] + (to[0] - from[0]) * t;
      const lng = from[1] + (to[1] - from[1]) * t;
      marker.setLatLng([lat, lng]);
      if (t < 1) {
        requestAnimationFrame(step);
      }
    };
    requestAnimationFrame(step);
  }

  private hashUid(uid: string): number {
    let h = 0;
    for (let i = 0; i < uid.length; i++) {
      h = (Math.imul(31, h) + uid.charCodeAt(i)) | 0;
    }
    return Math.abs(h);
  }

  /** Couleurs vives, stables par constatateur (hash uid). */
  private readonly markerPalette = [
    '#00f0ff',
    '#ffb300',
    '#ff3b6b',
    '#8b5cf6',
    '#22d3ee',
    '#34d399',
    '#fb7185',
    '#f97316',
    '#a3e635',
    '#60a5fa',
    '#f472b6',
    '#facc15'
  ];

  private agentColor(uid: string): string {
    return this.markerPalette[this.hashUid(uid) % this.markerPalette.length];
  }

  private blendWithMuted(hex: string, muted: string, t: number): string {
    const parse = (s: string) => {
      const x = s.replace('#', '');
      return [parseInt(x.slice(0, 2), 16), parseInt(x.slice(2, 4), 16), parseInt(x.slice(4, 6), 16)] as const;
    };
    const [r1, g1, b1] = parse(hex);
    const [r2, g2, b2] = parse(muted);
    const m = (a: number, b: number) => Math.round(a + (b - a) * t);
    const r = m(r1, r2);
    const g = m(g1, g2);
    const b = m(b1, b2);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  private createMarkerIcon(uid: string, hasPosition: boolean, isOffline = false): L.DivIcon {
    if (isOffline) {
      return this.createOfflineMarkerIcon(uid);
    }
    const base = this.agentColor(uid);
    const color = hasPosition ? base : this.blendWithMuted(base, '#4b5563', 0.42);
    const phase = (this.hashUid(`${uid}:phase`) % 100) / 100;
    const ringDelayA = (phase * 1.1).toFixed(2);
    const ringDelayB = ((phase + 0.45) * 1.1).toFixed(2);
    const svg = `
      <svg width="44" height="44" viewBox="0 0 30 30" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <radialGradient id="core-grad-${uid}" cx="50%" cy="42%" r="62%">
            <stop offset="0%" stop-color="#dbe4ff" stop-opacity="0.96" />
            <stop offset="100%" stop-color="${color}" stop-opacity="0.95" />
          </radialGradient>
        </defs>
        <circle
          class="agent-marker__ring agent-marker__ring--a"
          cx="15"
          cy="15"
          r="9"
          fill="none"
          stroke="${color}"
          stroke-opacity="0.85"
          stroke-width="1.8"
          style="animation-delay: ${ringDelayA}s"
        />
        <circle
          class="agent-marker__ring agent-marker__ring--b"
          cx="15"
          cy="15"
          r="9"
          fill="none"
          stroke="${color}"
          stroke-opacity="0.68"
          stroke-width="1.4"
          style="animation-delay: ${ringDelayB}s"
        />
        <circle class="agent-marker__halo" cx="15" cy="15" r="8.4" fill="${color}" fill-opacity="0.24" />
        <circle class="agent-marker__core" cx="15" cy="15" r="5.6" fill="url(#core-grad-${uid})" />
        <circle cx="15" cy="15" r="2" fill="#c7d2fe" fill-opacity="0.9" />
      </svg>
    `;
    return L.divIcon({
      className: hasPosition ? 'agent-marker agent-marker--active' : 'agent-marker',
      html: svg,
      iconSize: [44, 44],
      iconAnchor: [22, 22]
    });
  }

  /** Marqueur "hors ligne" : triangle d'alerte rouge avec point d'exclamation. */
  private createOfflineMarkerIcon(uid: string): L.DivIcon {
    const svg = `
      <svg width="44" height="44" viewBox="0 0 30 30" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <defs>
          <linearGradient id="offline-grad-${uid}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#fb7185" />
            <stop offset="100%" stop-color="#b91c1c" />
          </linearGradient>
        </defs>
        <polygon
          class="agent-marker__triangle"
          points="15,3 28,26 2,26"
          fill="url(#offline-grad-${uid})"
          stroke="#7f1d1d"
          stroke-width="1.2"
          stroke-linejoin="round"
        />
        <rect x="13.7" y="11" width="2.6" height="8" rx="1.1" fill="#fef2f2" />
        <circle cx="15" cy="22.2" r="1.5" fill="#fef2f2" />
      </svg>
    `;
    return L.divIcon({
      className: 'agent-marker agent-marker--offline',
      html: svg,
      iconSize: [44, 44],
      iconAnchor: [22, 26]
    });
  }

  private popupContent(c: Constatateur): string {
    const position = c.position_actuelle;
    const battery = position ? `${position.niveauBatterie}%` : 'N/A';
    const speed = position ? `${(position.vitesse * 3.6).toFixed(1)} km/h` : 'N/A';
    const lastDateTime = position
      ? new Date(position.timestamp).toLocaleString('fr-FR', {
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit'
        })
      : 'Position inconnue';
    return `
      <div class="popup">
        <strong>${c.infos.nom}</strong><br/>
        Statut: ${c.infos.statut}<br/>
        Batterie: ${battery}<br/>
        Vitesse: ${speed}<br/>
        Derniere position: ${lastDateTime}
      </div>
    `;
  }

  private shortAgentName(raw: string): string {
    const source = (raw ?? '').trim();
    if (!source) {
      return 'CONSTATATEUR';
    }
    const base = source.includes('@') ? source.split('@')[0] : source;
    const tokens = base
      .split(/[\s._-]+/)
      .map((t) => t.trim())
      .filter(Boolean);
    if (tokens.length >= 2) {
      return `${tokens[0]} ${tokens[1]}`.toUpperCase();
    }
    return (tokens[0] ?? 'CONSTATATEUR').toUpperCase();
  }

  private agentTooltipContent(uid: string, rawName: string, hasPosition: boolean, isOffline = false): string {
    const base = this.agentColor(uid);
    let bg: string;
    if (isOffline) {
      bg = '#7f1d1d';
    } else if (!hasPosition) {
      bg = this.blendWithMuted(base, '#4b5563', 0.42);
    } else {
      bg = base;
    }
    const fg = this.contrastTextColor(bg);
    const label = this.escapeHtml(this.shortAgentName(rawName));
    return `<span class="agent-name-badge__chip" style="background:${bg};color:${fg}">${label}</span>`;
  }

  private contrastTextColor(hex: string): string {
    const clean = hex.replace('#', '');
    if (clean.length !== 6) {
      return '#000000';
    }
    const r = parseInt(clean.slice(0, 2), 16);
    const g = parseInt(clean.slice(2, 4), 16);
    const b = parseInt(clean.slice(4, 6), 16);
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.6 ? '#000000' : '#ffffff';
  }

}
