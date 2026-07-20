# Day 5 · AWS III — Serverless: Lambda, SQS, SNS & CloudWatch

> So far every workload needed a *server* you launch, patch, and pay for around the clock. **Serverless** flips that: you hand AWS a function, and it runs — and bills — only when an event fires. Today you wire an **event-driven pipeline**: an upload to **S3** triggers a **Lambda** function, which publishes to an **SNS** topic that emails you; **SQS** buffers work between services; and **CloudWatch** gives you the logs, metrics, and scheduled events that tie it together. This is the glue of modern cloud architectures.

!!! note "Mostly free-tier friendly"
    Lambda (1M requests/mo), SNS, SQS, and CloudWatch have generous always-free tiers — today's lab costs effectively nothing. Still run the teardown so stray subscriptions don't nag you.

## Learning Objectives

- Explain the **serverless** model and when it beats a running server
- Write and deploy a **Lambda** function triggered by an event
- Decouple services with **SQS** (queues) and fan out with **SNS** (pub/sub)
- Read logs and fire scheduled jobs with **CloudWatch** (Logs + EventBridge)
- Build an **S3 → Lambda → SNS** pipeline end to end

---

## Prerequisites

- Day 3 (IAM + CLI). You'll create an execution **role** for Lambda — the role concept from Day 3 in action.

---

## Theory · ~20 min

### 1. What "serverless" means

There are still servers — you just don't manage them. You upload code; AWS provisions, scales, and tears down the runtime per invocation. You pay per **request** and **GB-second**, not per hour. Great for event handlers, glue, APIs with spiky traffic; a poor fit for long-running or stateful processes.

!!! tip "📺 Watch — *Serverless Computing in 100 Seconds* (Fireship)"
    The serverless model in ~2 minutes (with an optional full tutorial after).

    [![Serverless Computing in 100 Seconds](https://img.youtube.com/vi/W_VV2Fx32_Y/hqdefault.jpg){ width="360" }](https://youtu.be/W_VV2Fx32_Y)

### 2. Lambda

A **Lambda function** is code (Python, Node, Go…) plus a trigger. AWS runs it in response to **events** — an S3 upload, an SQS message, an API call, a schedule. Each function has:

- A **handler** — the entry point `def handler(event, context)`.
- An **execution role** — an IAM role granting what the function may touch (least privilege again).
- **Environment variables**, memory, and a timeout.

```python
def handler(event, context):
    for record in event["Records"]:
        key = record["s3"]["object"]["key"]
        print(f"New object: {key}")
    return {"statusCode": 200}
```

### 3. SQS — queues (decoupling)

**SQS** is a managed message **queue**. A producer drops messages in; consumers pull them at their own pace. It **decouples** services — if the consumer is slow or down, messages wait safely instead of being lost. One message → one consumer.

### 4. SNS — pub/sub (fan-out)

**SNS** is **publish/subscribe**. A publisher sends to a **topic**; every **subscriber** (email, SMS, Lambda, SQS queue) gets a copy. One message → many consumers. SQS = work distribution; SNS = broadcast. They're often combined (SNS → several SQS queues) in the "fan-out" pattern.

!!! tip "📺 Watch — *Back to Basics: Fan-Out with SNS, SQS & Lambda* (AWS, ~5 min)"
    Straight from AWS — the exact SNS + SQS + Lambda pattern behind today's pipeline.

    [![Fan-Out with SNS, SQS & Lambda](https://img.youtube.com/vi/CEj0yyubNgQ/hqdefault.jpg){ width="360" }](https://youtu.be/CEj0yyubNgQ)

### 5. CloudWatch

**CloudWatch** is the observability layer:

- **Logs** — every Lambda's `print`/stdout lands in a log group.
- **Metrics & Alarms** — numeric signals (CPU, invocation count, errors) you can alarm on.
- **Events / EventBridge** — a rule engine: run a Lambda **on a schedule** (cron) or when an AWS event matches a pattern.

---

## Lab · ~50 min

### Step 1 — Execution role for Lambda

Create an IAM role `golive-lambda-role` the Lambda service can assume, with the managed policies **`AWSLambdaBasicExecutionRole`** (for logs) and **`AmazonSNSFullAccess`** (to publish). Note its ARN.

### Step 2 — An SNS topic you subscribe to

```bash
TOPIC=$(aws sns create-topic --name golive-alerts --query 'TopicArn' --output text)
aws sns subscribe --topic-arn $TOPIC --protocol email \
  --notification-endpoint you@example.com
# ✋ check your inbox and CONFIRM the subscription
```

### Step 3 — Deploy the Lambda

```bash
cat > handler.py << 'EOF'
import os, boto3
sns = boto3.client("sns")
TOPIC = os.environ["TOPIC_ARN"]

def handler(event, context):
    for r in event.get("Records", []):
        key = r["s3"]["object"]["key"]
        sns.publish(TopicArn=TOPIC, Subject="New upload",
                    Message=f"Object uploaded to S3: {key}")
    return {"statusCode": 200}
EOF
zip function.zip handler.py

aws lambda create-function --function-name golive-notify \
  --runtime python3.12 --handler handler.handler \
  --role <golive-lambda-role-arn> \
  --environment "Variables={TOPIC_ARN=$TOPIC}" \
  --zip-file fileb://function.zip
```

### Step 4 — Wire S3 → Lambda

```bash
BUCKET=golive-uploads-$(date +%s)
aws s3 mb s3://$BUCKET

# Allow S3 to invoke the function
aws lambda add-permission --function-name golive-notify \
  --statement-id s3invoke --action lambda:InvokeFunction \
  --principal s3.amazonaws.com --source-arn arn:aws:s3:::$BUCKET

# Configure the bucket to notify the Lambda on object-created
aws s3api put-bucket-notification-configuration --bucket $BUCKET \
  --notification-configuration '{"LambdaFunctionConfigurations":[{
    "LambdaFunctionArn":"<golive-notify-arn>","Events":["s3:ObjectCreated:*"]}]}'
```

### Step 5 — Fire the pipeline

```bash
echo "hello serverless" > test.txt
aws s3 cp test.txt s3://$BUCKET/
# → within seconds you receive an EMAIL from SNS
```

Read the logs the function produced:

```bash
aws logs tail /aws/lambda/golive-notify --since 5m
```

### Step 6 — A scheduled job (EventBridge)

Create a rule that runs any Lambda every 5 minutes:

```bash
aws events put-rule --name golive-cron --schedule-expression "rate(5 minutes)"
# add the Lambda as the rule's target + grant events permission to invoke it
```

### Step 7 — 🔻 Teardown checklist

```bash
aws lambda delete-function --function-name golive-notify
aws sns delete-topic --topic-arn $TOPIC
aws s3 rb s3://$BUCKET --force
aws events delete-rule --name golive-cron            # remove targets first
aws iam delete-role --role-name golive-lambda-role   # detach policies first
```

Confirm no lingering **SNS subscriptions** (they'll keep emailing) and no **EventBridge rules** (they keep invoking).

---

## Advanced Topics

- **Fan-out** — subscribe two SQS queues to one SNS topic; each downstream service drains its own queue independently.
- **Dead-letter queues** — an SQS queue that catches messages a consumer repeatedly fails to process, so nothing is silently lost.
- **Lambda + API Gateway** — expose a function as an HTTP endpoint to build a serverless API.
- **Alarms** — a CloudWatch alarm on the Lambda `Errors` metric that publishes to your SNS topic when the function starts failing.

---

## Assignment

1. **Add a queue.** Insert SQS between S3 and processing: S3 → SNS → SQS, and write a second Lambda that drains the queue. Explain why the queue makes the system more resilient than S3 → Lambda directly.
2. **Alarm yourself.** Create a CloudWatch alarm on `golive-notify`'s error count that notifies your SNS topic. Force an error (break the handler) and show the alarm firing.
3. **Compare.** In a short paragraph, contrast SQS and SNS: message delivery model, number of consumers, and one real use case for each.

---

## Further Reading

**Watch**

- 📺 [Serverless Computing in 100 Seconds](https://youtu.be/W_VV2Fx32_Y) (Fireship) — the model, fast
- 📺 [Back to Basics: Fan-Out with SNS, SQS & Lambda](https://youtu.be/CEj0yyubNgQ) (AWS) — our exact pipeline, from the source
- 📺 [AWS Lambda: Getting Started](https://youtu.be/RtiWU1DrMaM) (KodeKloud) — a chaptered hands-on deep dive

**Reference**

- [AWS — Lambda](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [AWS — SQS](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/welcome.html) · [SNS](https://docs.aws.amazon.com/sns/latest/dg/welcome.html)
- [AWS — CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html) · [EventBridge](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html)
- [Serverless patterns collection](https://serverlessland.com/patterns) — copy-pasteable event-driven designs
