FROM python:3.10.7-slim

RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ nano

WORKDIR /src
COPY . .
RUN pip install -r requirements.txt

ENTRYPOINT ["python", "/src/run.py"]
