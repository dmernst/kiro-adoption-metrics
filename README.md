# kiro-adoption-metrics

Measure how your team uses Kiro, not just how much it spends. This repo turns Kiro's daily per-user activity report into Athena tables and five saved queries: active rate, depth, messages per conversation, model mix, and burn rate.

Companion to the blog post: [YOUR POST LINK]

![Architecture](docs/architecture.png)

## What it deploys

Everything runs in the AWS account and Region where your Kiro users are subscribed.

- **Report bucket** for Kiro's daily CSVs: Block Public Access, ACLs disabled, versioning, SSE-S3, TLS-only, and the Kiro write policy. Retained on delete, because it holds your history.
- **Athena results bucket**, with results expiring after 30 days.
- **Glue database and crawler**, scheduled at 03:30 UTC (after Kiro's 02:00 UTC report). It merges new model columns as they appear and keeps the IDE, CLI, and Plugin files in one table.
- **Athena workgroup with five saved queries** (also in [`queries/`](queries/)).

## Deploy

### CloudFormation (tested)

```bash
aws sts get-caller-identity   # confirm the account first
aws cloudformation deploy \
  --template-file cloudformation/kiro-adoption-metrics.yaml \
  --stack-name kiro-adoption-metrics \
  --capabilities CAPABILITY_IAM \
  --region <your Kiro profile Region>

aws cloudformation describe-stacks --stack-name kiro-adoption-metrics \
  --query "Stacks[0].Outputs[?OutputKey=='KiroReportS3Uri'].OutputValue" --output text
```

### Terraform

```bash
cd terraform
terraform init
terraform plan -var region=<your Kiro profile Region>
terraform apply -var region=<your Kiro profile Region>
terraform output -raw kiro_report_s3_uri
```

The Terraform version mirrors the CloudFormation template resource for resource. The CloudFormation version is the one deployed and tested end to end; run `terraform plan` and read it before applying.

## Turn on the report

1. **Kiro console > Access management:** make sure at least one user shows **Seated**. A report with no seated users is an empty report.
2. **Kiro console > Settings > Usage activity > Kiro user activity report > Manage:** choose **CSV report per Kiro client type**, paste the S3 URI output, and choose **Enable**.

The report is written **once a day at 02:00 UTC**. It doesn't stream, and the schedule isn't configurable. Each row covers one user for one UTC day.

## Run the queries

After the first file lands, start the crawler (or wait for 03:30 UTC), then open Athena, switch to the stack's workgroup, and run the saved queries in order:

| Query | What it answers |
|---|---|
| `0-check-rows-per-day` | Is data landing every day? |
| `1-list-model-columns` | Which `<model>_messages` columns exist today? Paste them into query 3. |
| `2-active-users-depth-messages-per-conversation-7-days` | Unique active users, depth gap and ratio (per active user-day), and messages per conversation, a proxy for interaction depth. Last 7 complete UTC days. |
| `3-model-mix-30-days-edit-the-arrays-first` | Share of messages by model. `model_a`/`model_b` are placeholders: replace them with query 1's columns, and update after new models appear. |
| `4-burn-rate-and-tier-fit-month-to-date` | **Individual subscriptions with overage disabled only.** Percent of cap, remaining credits, and estimated days remaining at the current average daily pace (an estimate, not a forecast). On credit sharing, there's no per-user cap: watch the shared pool in the Kiro console dashboard. |

## Gotchas

- **The schema changes daily.** A `<model>_messages` column appears only on days someone used that model. The crawler merges new columns; older days return null for newer models.
- **`date` is a reserved word in Athena.** Quote it as `"date"`. It's a UTC day. The queries compute today as `date(current_timestamp AT TIME ZONE 'UTC')` so the boundary doesn't depend on the session time zone, and they stop at yesterday because today's report lands at 02:00 UTC tomorrow.
- **The crawler keeps CSV quotes.** `userid` comes back as `"…"`; use `trim(BOTH '"' FROM userid)` before joining.
- **Files only for clients used.** No CLI file means nobody used the CLI that day. The date folder is the activity date.
- **Credit sharing rows** show `subscription_tier = POOLING`, `overage_cap = 0`, and an undocumented `usage_limit` column (999999 when no limit is set).
- **The crawler lowercases column names.** `Total_Messages` becomes `total_messages`.
- **The report includes `User_Email`.** Restrict who can read the bucket.
- **Credit sharing changes burn rate.** Seats contribute 500 credits a month each to a shared pool (prorated in the first month), with no overages. Measure the pool, not per-user caps.
- **Cross-account buckets aren't supported.** Deploy one stack per account where users are subscribed.

## Cost

A few cents a month for S3, Glue crawler runs, and Athena scans at small-team scale. Check current pricing for your Region.

## License

MIT-0
