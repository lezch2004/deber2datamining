# Capa 1: imagen base
FROM python:3.10-slim

# Configurar directorio de trabajo ADENTRO del contenedor
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copiar los archivos locales AL contenedor
COPY . /app

# Comando para ejecutar el script de python
CMD ["python", "ingest-data.py"]
