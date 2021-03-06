select c1.concept_id as concept_id,
	'Length of era' as category,
	ard1.min_value as min_value,
	ard1.p10_value as p10_value,
	ard1.p25_value as p25_value,
	ard1.median_value as median_value,
	ard1.p75_value as p75_value,
	ard1.p90_value as p90_value,
	ard1.max_value as max_value
from ACHILLES_results_dist ard1
	inner join @cdmSchema.dbo.concept c1 on CAST(ard1.stratum_1 as INT) = c1.concept_id
where ard1.analysis_id = 1007 and ard1.count_value > 0


