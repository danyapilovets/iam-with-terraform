FROM python:3.11-alpine

RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt ./requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

WORKDIR /app
COPY ./main.py /app/main.py
COPY ./db_connect_events.py /app/db_connect_events.py

ENTRYPOINT ["python", "main.py"]
