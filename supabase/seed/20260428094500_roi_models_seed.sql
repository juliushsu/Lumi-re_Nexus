begin;

insert into public.roi_models (
  model_name,
  model_type,
  market_region,
  model_version,
  description,
  budget_min,
  budget_max,
  expected_roi_min,
  expected_roi_max,
  payback_months_min,
  payback_months_max,
  risk_level,
  assumptions_json,
  formula_version,
  status,
  is_active
)
select *
from (
  values
    (
      'micro_feature_film',
      'feature_film',
      'APAC',
      'v1',
      'Low-budget scripted feature with festival upside and limited downside protection.',
      500000.00::numeric,
      3000000.00::numeric,
      0.1200::numeric,
      0.3500::numeric,
      24,
      60,
      'medium',
      '{
        "distribution_mix": ["festival_sales", "regional_theatrical", "svod"],
        "capital_stack": {"equity": 0.7, "soft_money": 0.3},
        "key_assumptions": {
          "festival_selection_probability": 0.28,
          "minimum_guarantee_probability": 0.35,
          "marketing_to_budget_ratio_max": 0.4
        }
      }'::jsonb,
      'roi_formula_v1',
      'active',
      true
    ),
    (
      'commercial_video_project',
      'commercial',
      'Global',
      'v1',
      'Short-cycle branded content project prioritizing contracted revenue and low recoup variance.',
      100000.00::numeric,
      1500000.00::numeric,
      0.0800::numeric,
      0.2200::numeric,
      6,
      18,
      'low',
      '{
        "distribution_mix": ["brand_contract", "usage_extension", "library_reuse"],
        "capital_stack": {"equity": 0.5, "prepayment": 0.5},
        "key_assumptions": {
          "client_collection_probability": 0.96,
          "scope_change_buffer": 0.1,
          "gross_margin_floor": 0.22
        }
      }'::jsonb,
      'roi_formula_v1',
      'active',
      true
    ),
    (
      'streaming_series',
      'series',
      'Global',
      'v1',
      'Multi-episode streaming series with platform-fit weighting and amortized development overhead.',
      3000000.00::numeric,
      25000000.00::numeric,
      0.1500::numeric,
      0.4500::numeric,
      18,
      48,
      'medium',
      '{
        "distribution_mix": ["platform_license", "output_deal", "secondary_windows"],
        "capital_stack": {"equity": 0.6, "gap": 0.15, "presale": 0.25},
        "key_assumptions": {
          "renewal_probability": 0.42,
          "subscriber_lift_proxy_weight": 0.35,
          "completion_bond_required": true
        }
      }'::jsonb,
      'roi_formula_v1',
      'active',
      true
    ),
    (
      'international_coproduction',
      'feature_film',
      'EMEA_APAC',
      'v1',
      'Treaty-based co-production model with cross-border financing and elevated delivery complexity.',
      2000000.00::numeric,
      18000000.00::numeric,
      0.1400::numeric,
      0.3800::numeric,
      24,
      72,
      'medium_high',
      '{
        "distribution_mix": ["territory_presales", "public_funds", "all_rights_sales"],
        "capital_stack": {"equity": 0.45, "public_funds": 0.25, "presale": 0.3},
        "key_assumptions": {
          "fx_reserve_ratio": 0.08,
          "coordinator_overhead_ratio": 0.05,
          "cross_border_clearance_risk": 0.3
        }
      }'::jsonb,
      'roi_formula_v1',
      'active',
      true
    ),
    (
      'experimental_high_risk',
      'experimental',
      'Global',
      'v1',
      'High-volatility slate candidate for prestige upside, with asymmetric downside and uncertain monetization path.',
      250000.00::numeric,
      8000000.00::numeric,
      -0.2500::numeric,
      0.9000::numeric,
      36,
      96,
      'high',
      '{
        "distribution_mix": ["festival_discovery", "grants", "catalog_value"],
        "capital_stack": {"equity": 0.85, "grant": 0.15},
        "key_assumptions": {
          "breakout_probability": 0.12,
          "downside_loss_cap": 0.7,
          "talent_attachment_dependency": 0.6
        }
      }'::jsonb,
      'roi_formula_v1',
      'active',
      true
    )
) as seed_data (
  model_name,
  model_type,
  market_region,
  model_version,
  description,
  budget_min,
  budget_max,
  expected_roi_min,
  expected_roi_max,
  payback_months_min,
  payback_months_max,
  risk_level,
  assumptions_json,
  formula_version,
  status,
  is_active
)
where not exists (
  select 1
  from public.roi_models rm
  where rm.model_name = seed_data.model_name
);

commit;
