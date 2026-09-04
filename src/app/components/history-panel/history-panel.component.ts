import { CommonModule, DatePipe } from '@angular/common';
import { Component, EventEmitter, Input, OnChanges, OnDestroy, Output, SimpleChanges } from '@angular/core';
import * as L from 'leaflet';
import { HistoriqueEntry } from '../../models/constatateur.model';

@Component({
  selector: 'app-history-panel',
  standalone: true,
  imports: [CommonModule, DatePipe],
  templateUrl: './history-panel.component.html',
  styleUrl: './history-panel.component.scss'
})
export class HistoryPanelComponent implements OnChanges, OnDestroy {
  @Input() map: L.Map | null = null;
  @Input() historique: HistoriqueEntry[] = [];
  @Input() visible = false;
  @Output() close = new EventEmitter<void>();

  private historyLayer: L.LayerGroup | null = null;

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['historique'] || changes['visible'] || changes['map']) {
      this.renderHistoryPoints();
    }
  }

  ngOnDestroy(): void {
    this.clearHistoryLayer();
  }

  onClose(): void {
    this.clearHistoryLayer();
    this.close.emit();
  }

  private renderHistoryPoints(): void {
    this.clearHistoryLayer();
    if (!this.map || !this.visible || this.historique.length === 0) {
      return;
    }

    const group = L.layerGroup();
    for (const h of this.historique) {
      const circle = L.circleMarker([h.latitude, h.longitude], {
        radius: 6,
        color: '#00e5ff',
        weight: 2,
        fillColor: '#00e5ff',
        fillOpacity: 0.75
      });
      circle.bindPopup(this.popupContent(h));
      circle.addTo(group);
    }
    group.addTo(this.map);
    this.historyLayer = group;

    this.fitMapToHistory();
  }

  private fitMapToHistory(): void {
    if (!this.map || this.historique.length === 0) {
      return;
    }
    if (this.historique.length === 1) {
      const h = this.historique[0];
      this.map.setView([h.latitude, h.longitude], 15, { animate: true });
      return;
    }
    const bounds = L.latLngBounds(
      this.historique.map((h) => [h.latitude, h.longitude] as L.LatLngTuple)
    );
    this.map.fitBounds(bounds, { padding: [40, 40], maxZoom: 16, animate: true });
  }

  private popupContent(h: HistoriqueEntry): string {
    const lastDateTime = new Date(h.timestamp).toLocaleString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
    const speed = `${(h.vitesse * 3.6).toFixed(1)} km/h`;
    return `
      <div class="popup">
        <strong>Position</strong><br/>
        ${lastDateTime}<br/>
        Batterie: ${h.niveauBatterie}%<br/>
        Vitesse: ${speed}<br/>
        Mode: ${h.modeTracking}
      </div>
    `;
  }

  private clearHistoryLayer(): void {
    if (this.historyLayer && this.map) {
      this.map.removeLayer(this.historyLayer);
    }
    this.historyLayer = null;
  }
}
