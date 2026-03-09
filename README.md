# DEBER 2 DATA MINING 
Nombre: Luis Eduardo Zaldumbide
Código: 00330842

# 1. Arquitectura(bronze/silver/gold)
El proyecto sigue la implementación de un pipeline ELT de datos con el fin de generar una estructura de medallas, y un notebook basado en gold que responde 20 preguntas de negocio. 

La base de la infraestructura es Docker, pues ha sido utilizado para levantar los contenedores que sostienen la infraestructura necesaria para el proyecto. Esto incluye postgres (la base de datos), pgadmin(el gestor ui de la base de datos), mage(orquestador) que también es el que sostiene dbt y realmente controla los triggers y todo el proyecto de manera automatizada, y jupyter que es utilizado para generar el notebook. 

Las capas siguen la siguiente arquitectura de medallions: 

## capa bronze
- datos extraídos de su origen, descargados en parquet, por año, mes y tipo de servicio, con chunking de 100,000 filas.
- el origen es: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- se mantiene la estructura original de los datos añadiendo meta datos de el tiempo de ingesta, año, mes y tipo de servicio. De igual manera se hace un formateo de columnas para que exista igualdad entre las filas de tipo yellow y green.
- Esto se logra a traves de un pipeline padre (ingest_bronze) que llama a un pipeline hijo (taxi_trips_ingest). El pipeline padre genera las combinaciones de fecha y tipo de servicio y llama uno por uno al pipeline hijo, para que este aplique la descarga y carga a postgres mediante chunking, asegurando la idempotencia del pipeline al borrar los datos correspondientes a ese chunk.
- además se realiza una pequeña limpieza de las columnas con dbt y se carga el csv de zones.

## capa silver 
- enriquecimiento de los datos de trips con la tabla zones.
- limpieza de columnas y verificaciones con schema.yml que genera pruebas para verificar que los valores sean lógicos, que tengan unión con sus metadatos y que no estén nulos.
- materialización como views.

## capa gold
- está es la capa refinada donde el notebook obtiene sus datos.
- se generan macros para lograr el particionamiento y de ahí se utiliza dbt para lograr la ingesta del modelo por dimensiones.
- star schema.
- mejora del rendimiento y partitioning pruning.

## gráfico 
    A[NYC TLC] -->|ingest_bronze| *aterriza los datos en mage y de ahí en postgres
    B[(Postgres: Bronze)] -->|dbt run silver| *medallion silver.
    C[Postgres: Silver Views] -->|dbt run gold| *medallion gold
    D[(Postgres: Gold Tables)]-->|análisis en notebook| 
    E[Jupyter Notebook] *entregable con respuestas a preguntas de negocio
    
    Los pasos A a las D son orquestados por Mage.
    




