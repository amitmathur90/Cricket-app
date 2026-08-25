import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Organization } from './organization.entity';
import { Tournament } from './tournament.entity';
import { User } from './user.entity';

/**
 * Manually-recorded finance categories — everything the Finance dashboard
 * needs that ISN'T derivable from existing data (registration fees, auction
 * sale prices). See FinanceService's dashboard doc comment for how each
 * category rolls up into the revenue/expense breakdown, and in particular
 * for how `sponsorship` here relates to the (separately built) `Sponsor`
 * entity's `amount` field — short version: `Sponsor.amount` is the
 * authoritative source for ongoing sponsorship deals; `category:
 * sponsorship` rows here are for one-off sponsorship income NOT already
 * captured there (e.g. a single-event cash sponsorship with no full Sponsor
 * profile). The two are summed, not deduped, by design.
 */
export enum FinanceTransactionCategory {
  SPONSORSHIP = 'sponsorship',
  GROUND_EXPENSE = 'ground_expense',
  OFFICIALS_PAYMENT = 'officials_payment',
  OTHER_EXPENSE = 'other_expense',
  OTHER_INCOME = 'other_income',
}

export enum FinanceTransactionType {
  INCOME = 'income',
  EXPENSE = 'expense',
}

/**
 * Every category above has exactly one valid `type` — enforced in
 * FinanceService (not at the DB layer, consistent with how this codebase
 * validates cross-field business rules elsewhere, e.g. captain/vice-captain
 * exclusivity in TeamsService) — so the dashboard can safely group
 * `type: expense` rows by category without a row ever landing in the wrong
 * bucket.
 */
export const FINANCE_CATEGORY_TYPE: Record<FinanceTransactionCategory, FinanceTransactionType> = {
  [FinanceTransactionCategory.SPONSORSHIP]: FinanceTransactionType.INCOME,
  [FinanceTransactionCategory.OTHER_INCOME]: FinanceTransactionType.INCOME,
  [FinanceTransactionCategory.GROUND_EXPENSE]: FinanceTransactionType.EXPENSE,
  [FinanceTransactionCategory.OFFICIALS_PAYMENT]: FinanceTransactionType.EXPENSE,
  [FinanceTransactionCategory.OTHER_EXPENSE]: FinanceTransactionType.EXPENSE,
};

/**
 * A single manually-recorded income/expense entry — sponsorship cash,
 * ground rental, umpire/scorer payments, and anything else that doesn't
 * already exist as structured data elsewhere in the schema. Deliberately
 * does NOT cover auction purse movements (`purse_ledger` is the source of
 * truth there) or registration fees (derived on read from
 * `Tournament.playerRegistrationFee`/`teamRegistrationFee` × actual
 * registered counts) — see FinanceService for those derivations.
 */
@Entity({ name: 'finance_transactions' })
export class FinanceTransaction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  /** Null = org-wide entry, not attributable to a single tournament. */
  @Index()
  @Column({ name: 'tournament_id', type: 'uuid', nullable: true })
  tournamentId: string | null;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament | null;

  @Column({ type: 'enum', enum: FinanceTransactionCategory })
  category: FinanceTransactionCategory;

  @Column({ type: 'enum', enum: FinanceTransactionType })
  type: FinanceTransactionType;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  /** The date the transaction is attributed to (e.g. date of expense/payment) — not `createdAt`. */
  @Column({ name: 'reference_date', type: 'date' })
  referenceDate: string;

  @Column({ name: 'created_by_user_id', type: 'uuid' })
  createdByUserId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_user_id' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
