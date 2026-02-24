# Build stage
FROM python:3.12-slim AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt

# Deploy stage
FROM python:3.12-slim AS runner

ENV TZ=Asia/Ho_Chi_Minh

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    cron \
    tzdata \
    bash \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd -r cystack && useradd -r -g cystack -s /usr/sbin/nologin -c "CyStack user" -m cystack

# Virtualenv
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# App code
COPY src .

# Cron job: 9h sáng thứ 2 hàng tuần
RUN echo "0 9 * * 2 root bash -c 'set -a; source /tmp/intel-report.env; set +a; /opt/venv/bin/python3 /app/intel_report_cron.py >> /var/log/intel-report.log 2>&1'" \
    > /etc/cron.d/intel-report \
 && chmod 0644 /etc/cron.d/intel-report \
 && crontab /etc/cron.d/intel-report

# Log file
RUN touch /var/log/intel-report.log

#USER cystack

# Start cron
CMD sh -c "\
env > /tmp/intel-report.env && \
cron && \
tail -f /var/log/intel-report.log"

