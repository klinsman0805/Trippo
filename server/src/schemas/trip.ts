import { z } from 'zod';
import { PaceSchema } from './plan.js';

const DateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD');

export const MemberInputSchema = z.object({
  name: z.string().min(1),
  departure_city: z.string().optional(),
  interests: z.array(z.string()).default([]),
  pace: PaceSchema.default('moderate'),
  budget_sensitivity: z.string().optional(),
  dietary_restrictions: z.array(z.string()).default([]),
  accessibility_needs: z.array(z.string()).default([]),
  deal_breakers: z.array(z.string()).default([]),
  wants: z.array(z.string()).default([]),
  avoids: z.array(z.string()).default([]),
});
export type MemberInput = z.infer<typeof MemberInputSchema>;

export const TripInputSchema = z.object({
  title: z.string().min(1),
  destinations: z.array(z.string()).default([]),
  start_date: DateStr.nullable().optional(),
  end_date: DateStr.nullable().optional(),
  date_flexible: z.boolean().default(true),
  currency: z.string().length(3).default('USD'),
  total_budget: z.number().positive().nullable().optional(),
  budget_basis: z.enum(['total', 'per_person']).default('total'),
  purpose: z.string().optional(),
  hard_constraints: z.array(z.string()).default([]),
  notes: z.string().optional(),
  members: z.array(MemberInputSchema).default([]),
});
export type TripInput = z.infer<typeof TripInputSchema>;

export const TripPatchSchema = TripInputSchema.omit({ members: true }).partial();

export interface Member extends MemberInput {
  id: string;
  trip_id: string;
  created_at: string;
}

export interface Trip {
  id: string;
  title: string;
  destinations: string[];
  start_date: string | null;
  end_date: string | null;
  date_flexible: boolean;
  currency: string;
  total_budget: number | null;
  budget_basis: 'total' | 'per_person';
  purpose: string | null;
  hard_constraints: string[];
  notes: string | null;
  created_at: string;
  updated_at: string;
  members: Member[];
}

export interface Place {
  id: string;
  trip_id: string;
  source_id: string | null;
  name: string;
  category: string | null;
  city: string | null;
  country: string | null;
  address: string | null;
  lat: number | null;
  lng: number | null;
  google_place_id: string | null;
  why: string | null;
  tags: string[];
  resolved: boolean;
  created_at: string;
}
