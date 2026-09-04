import { Injectable, inject } from '@angular/core';
import { Database } from '@angular/fire/database';
import { DataSnapshot, get, onValue, query, ref, limitToLast } from 'firebase/database';
import { from, map, Observable } from 'rxjs';
import { Constatateur, HistoriqueEntry } from '../models/constatateur.model';

@Injectable({ providedIn: 'root' })
export class ConstatateursService {
  private readonly db = inject(Database);

  getAll$(): Observable<Constatateur[]> {
    return new Observable<Constatateur[]>((subscriber) => {
      const dbRef = ref(this.db, 'constatateurs');
      const unsubscribe = onValue(
        dbRef,
        (snapshot) => subscriber.next(this.mapConstatateurs(snapshot)),
        (error) => subscriber.error(error)
      );
      return () => unsubscribe();
    });
  }

  /** Lecture ponctuelle (ex. rafraîchissement périodique). */
  refreshConstatateurs$(): Observable<Constatateur[]> {
    const dbRef = ref(this.db, 'constatateurs');
    return from(get(dbRef)).pipe(map((snapshot) => this.mapConstatateurs(snapshot)));
  }

  getHistorique$(uid: string): Observable<HistoriqueEntry[]> {
    return new Observable<HistoriqueEntry[]>((subscriber) => {
      const historiqueRef = query(ref(this.db, `constatateurs/${uid}/historique`), limitToLast(50));
      const unsubscribe = onValue(
        historiqueRef,
        (snapshot) => subscriber.next(this.mapHistorique(snapshot)),
        (error) => subscriber.error(error)
      );
      return () => unsubscribe();
    });
  }

  connected$(): Observable<boolean> {
    return new Observable<boolean>((subscriber) => {
      const infoRef = ref(this.db, '.info/connected');
      const unsubscribe = onValue(
        infoRef,
        (snapshot) => subscriber.next(snapshot.val() === true),
        (error) => subscriber.error(error)
      );
      return () => unsubscribe();
    });
  }

  private mapConstatateurs(snapshot: DataSnapshot): Constatateur[] {
    if (!snapshot.exists()) {
      return [];
    }
    const data = snapshot.val() as Record<string, Omit<Constatateur, 'uid'>>;
    return Object.entries(data).map(([uid, value]) => ({
      uid,
      infos: value.infos,
      position_actuelle: value.position_actuelle ?? null
    }));
  }

  private mapHistorique(snapshot: DataSnapshot): HistoriqueEntry[] {
    if (!snapshot.exists()) {
      return [];
    }
    const raw = snapshot.val() as Record<string, Omit<HistoriqueEntry, 'id'>>;
    return Object.entries(raw)
      .map(([id, value]) => ({ id, ...value }))
      .sort((a, b) => a.timestamp - b.timestamp);
  }
}
