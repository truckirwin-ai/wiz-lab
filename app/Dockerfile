# Intentionally using an older base image to generate Trivy findings
FROM python:3.9-slim

WORKDIR /app

# No non-root user (intentional misconfiguration)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py wizexercise.txt ./

EXPOSE 5000

CMD ["python", "app.py"]
