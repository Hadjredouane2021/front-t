export type StatutConstatateur = 'DISPONIBLE' | 'EN_MISSION' | 'INDISPONIBLE';
export type ModeTracking = 'STATIONNAIRE' | 'EN_MOUVEMENT';

export interface InfosConstatateur {
  nom: string;
  statut: StatutConstatateur;
  actif: boolean;
  telephone: string;
  androidId: string;
}

export interface PositionActuelle {
  latitude: number;
  longitude: number;
  modeTracking: ModeTracking;
  niveauBatterie: number;
  vitesse: number;
  precision: number;
  timestamp: number;
}

export interface HistoriqueEntry {
  id?: string;
  latitude: number;
  longitude: number;
  modeTracking: ModeTracking;
  niveauBatterie: number;
  vitesse: number;
  timestamp: number;
}

export interface Constatateur {
  uid: string;
  infos: InfosConstatateur;
  position_actuelle: PositionActuelle | null;
}
