import { CommonModule, DatePipe } from '@angular/common';
import { Component, EventEmitter, Input, Output, computed, signal } from '@angular/core';
import { Constatateur } from '../../models/constatateur.model';
import {
  EffectiveStatus,
  getEffectiveStatus,
  isPositionStale,
  relativePositionAge
} from '../../utils/constatateur-status.util';

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [CommonModule, DatePipe],
  templateUrl: './sidebar.component.html',
  styleUrl: './sidebar.component.scss'
})
export class SidebarComponent {
  @Input() set constatateurs(value: Constatateur[]) {
    this._constatateurs.set(value ?? []);
  }

  @Input() selectedId: string | null = null;
  @Output() selectConstatateur = new EventEmitter<string>();
  @Output() showHistorique = new EventEmitter<string>();

  private readonly _constatateurs = signal<Constatateur[]>([]);

  readonly filteredConstatateurs = computed(() =>
    [...this._constatateurs()].sort((a, b) => a.infos.nom.localeCompare(b.infos.nom, 'fr', { sensitivity: 'base' }))
  );

  trackByUid(_: number, item: Constatateur): string {
    return item.uid;
  }

  private hashUid(uid: string): number {
    let h = 0;
    for (let i = 0; i < uid.length; i++) {
      h = (Math.imul(31, h) + uid.charCodeAt(i)) | 0;
    }
    return Math.abs(h);
  }

  /** Palette identique a la carte pour garder les couleurs synchronisees. */
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

  agentColor(uid: string): string {
    return this.markerPalette[this.hashUid(uid) % this.markerPalette.length];
  }

  effectiveStatus(c: Constatateur): EffectiveStatus {
    return getEffectiveStatus(c);
  }

  isStale(c: Constatateur): boolean {
    return isPositionStale(c.position_actuelle?.timestamp ?? null);
  }

  positionAge(c: Constatateur): string {
    return relativePositionAge(c.position_actuelle?.timestamp ?? null);
  }
}
