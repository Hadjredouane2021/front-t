import { CommonModule } from '@angular/common';
import { Component, OnDestroy, signal } from '@angular/core';
import * as L from 'leaflet';
import { Subject, Subscription, switchMap, takeUntil, timer } from 'rxjs';
import { HistoryPanelComponent } from './components/history-panel/history-panel.component';
import { MapComponent } from './components/map/map.component';
import { SidebarComponent } from './components/sidebar/sidebar.component';
import { Constatateur, HistoriqueEntry } from './models/constatateur.model';
import { ConstatateursService } from './services/constatateurs.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, SidebarComponent, MapComponent, HistoryPanelComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent implements OnDestroy {
  readonly constatateurs = signal<Constatateur[]>([]);
  readonly selectedId = signal<string | null>(null);
  readonly historique = signal<HistoriqueEntry[]>([]);
  readonly showHistory = signal(false);
  readonly isConnected = signal(false);
  readonly firebaseError = signal<string | null>(null);
  /** Menu latéral liste des constatateurs */
  readonly sidebarOpen = signal(true);

  mapInstance: L.Map | null = null;
  private readonly destroy$ = new Subject<void>();
  private historySub?: Subscription;

  constructor(private readonly constatateursService: ConstatateursService) {
    this.constatateursService
      .getAll$()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (agents) => {
          this.firebaseError.set(null);
          this.applyConstatateursSnapshot(agents);
        },
        error: (error) => {
          console.error('Erreur lecture constatateurs', error);
          this.firebaseError.set("Lecture Firebase refusee. Verifie les regles Realtime Database.");
          this.constatateurs.set([]);
        }
      });

    this.constatateursService
      .connected$()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (connected) => this.isConnected.set(connected),
        error: (error) => {
          console.error('Erreur connexion Firebase', error);
          this.isConnected.set(false);
        }
      });

    timer(30_000, 30_000)
      .pipe(
        takeUntil(this.destroy$),
        switchMap(() => this.constatateursService.refreshConstatateurs$())
      )
      .subscribe({
        next: (agents) => {
          this.firebaseError.set(null);
          this.applyConstatateursSnapshot(agents);
        },
        error: (error) => {
          console.error('Erreur rafraichissement constatateurs', error);
          this.firebaseError.set("Lecture Firebase refusee. Verifie les regles Realtime Database.");
        }
      });
  }

  toggleSidebar(): void {
    this.sidebarOpen.update((open) => !open);
    this.invalidateMapSizeSoon();
  }

  /** Leaflet garde la taille initiale du conteneur : il faut invalider après changement de layout (menu latéral). */
  private invalidateMapSizeSoon(): void {
    const map = this.mapInstance;
    if (!map) {
      return;
    }
    const inv = (): void => {
      map.invalidateSize({ animate: false });
    };
    requestAnimationFrame(() => {
      inv();
      requestAnimationFrame(inv);
    });
    setTimeout(inv, 0);
    setTimeout(inv, 340);
  }

  onSelect(uid: string): void {
    this.selectedId.set(uid);
  }

  onRequestHistory(uid: string): void {
    this.selectedId.set(uid);
    this.historySub?.unsubscribe();
    this.historySub = this.constatateursService
      .getHistorique$(uid)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (entries) => {
          this.historique.set(entries);
          this.showHistory.set(true);
        },
        error: (error) => {
          console.error('Erreur historique', error);
          this.firebaseError.set("Impossible de lire l'historique Firebase.");
        }
      });
  }

  onCloseHistory(): void {
    this.historySub?.unsubscribe();
    this.historySub = undefined;
    this.showHistory.set(false);
    this.historique.set([]);
  }

  onMapReady(map: L.Map): void {
    // Evite NG0100: le child emet pendant l'init, on commit la valeur au tick suivant.
    queueMicrotask(() => {
      this.mapInstance = map;
      this.invalidateMapSizeSoon();
    });
  }

  ngOnDestroy(): void {
    this.historySub?.unsubscribe();
    this.destroy$.next();
    this.destroy$.complete();
  }

  /**
   * Met à jour le signal seulement si les données ont changé (évite de rerendre
   * toute la page / la liste quand rien n’a bougé).
   */
  private applyConstatateursSnapshot(incoming: Constatateur[]): void {
    const prev = this.constatateurs();
    const prevMap = new Map(prev.map((c) => [c.uid, c]));

    if (!this.sameUidSets(prev, incoming)) {
      this.constatateurs.set(this.reconcileConstatateurs(prevMap, incoming));
      return;
    }

    let anyChange = false;
    const next: Constatateur[] = incoming.map((inc) => {
      const old = prevMap.get(inc.uid)!;
      if (this.sameConstatateurSnapshot(old, inc)) {
        return old;
      }
      anyChange = true;
      return { ...old, infos: inc.infos, position_actuelle: inc.position_actuelle };
    });

    if (!anyChange) {
      return;
    }
    this.constatateurs.set(next);
  }

  private sameUidSets(prev: Constatateur[], incoming: Constatateur[]): boolean {
    if (prev.length !== incoming.length) {
      return false;
    }
    const prevUids = new Set(prev.map((c) => c.uid));
    for (const inc of incoming) {
      if (!prevUids.has(inc.uid)) {
        return false;
      }
    }
    return true;
  }

  private reconcileConstatateurs(
    prevMap: Map<string, Constatateur>,
    incoming: Constatateur[]
  ): Constatateur[] {
    return incoming.map((inc) => {
      const old = prevMap.get(inc.uid);
      if (old && this.sameConstatateurSnapshot(old, inc)) {
        return old;
      }
      if (old) {
        return { ...old, infos: inc.infos, position_actuelle: inc.position_actuelle };
      }
      return inc;
    });
  }

  private sameConstatateurSnapshot(a: Constatateur, b: Constatateur): boolean {
    return a.uid === b.uid && this.sameInfos(a.infos, b.infos) && this.samePosition(a.position_actuelle, b.position_actuelle);
  }

  private sameInfos(a: Constatateur['infos'], b: Constatateur['infos']): boolean {
    return (
      a.nom === b.nom &&
      a.statut === b.statut &&
      a.actif === b.actif &&
      a.telephone === b.telephone &&
      a.androidId === b.androidId
    );
  }

  private samePosition(a: Constatateur['position_actuelle'], b: Constatateur['position_actuelle']): boolean {
    if (a === b) {
      return true;
    }
    if (!a && !b) {
      return true;
    }
    if (!a || !b) {
      return false;
    }
    return (
      a.latitude === b.latitude &&
      a.longitude === b.longitude &&
      a.timestamp === b.timestamp &&
      a.niveauBatterie === b.niveauBatterie &&
      a.vitesse === b.vitesse &&
      a.modeTracking === b.modeTracking &&
      a.precision === b.precision
    );
  }
}
