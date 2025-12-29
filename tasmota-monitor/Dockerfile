FROM python:3.9-slim

WORKDIR /app

# Installiere benötigte Pakete
RUN pip install streamlit pandas requests matplotlib

# Kopiere das Skript
COPY app.py .

# Erstelle Daten-Ordner
RUN mkdir data

# Starte Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]