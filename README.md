# DEBER 2 DATA MINING 
Nombre: Luis Eduardo Zaldumbide
Código: 00330842

# 1. Arquitectura(bronze/silver/gold)
El proyecto sigue la implementación de un pipeline ELT de datos con el fin de generar una estructura de medallas, y un notebook basado en gold que responde 20 preguntas de negocio. 

La base de la infraestructura es Docker, pues ha sido utilizado para levantar los contenedores que sostienen la infraestructura necesaria para el proyecto. Esto incluye postgres (la base de datos), pgadmin(el gestor ui de la base de datos), mage(orquestador) que también es el que sostiene dbt y realmente controla los triggers y todo el proyecto de manera automatizada, y mage notebooks que es utilizado para generar el notebook. 

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
    E[Mage Notebook] *entregable con respuestas a preguntas de negocio
    
    Los pasos A a las D son orquestados por Mage.

# 2. Tabla de cobertura
Como ya ha sido mencionado, la ingesta de los datos es realizado por el pipeline de ingest_bronze (pipeline padre) y su trigger ingest_monthly. Este pipeline lo que hace es generar combinaciones de fecha y tipo de servicio para que el pipeline hijo taxi_trips_ingest reciba llamadas APIs que resuelve al descargar los parquets y cargarlos. Para asegurar que exista idempotencia, antes de cargar un nuevo segmento de datos, se borra cualquier dato que contenga ese segmento de metadatos, asegurando que no haya datos repetidos. De igual manera, para asegurar la integridad del pipeline, las llamadas son uno por uno, esperando que se acaben y poniendo una pausa entre las ejecuciones. Adicionalmente, además del chunking por segmento de fecha y tipo de servicio, se genera un chunking interno de 100,000 filas para ir cargando al postgres. 

Durante la realización del proyecto entero, se ha logrado cargar todos los datos entre 2022-2025 de yellow y green para los meses disponibles, con un total de aproximadamente 165 millones de filas. Sin embargo, esta cantidad de datos ha sido muy dificil de procesar con la memoria disponible en el computador donde se ha corrido el pipeline. Por esta razón, se ha decidido trabajar los resultados con solo datos de yellow y green de los meses disponibles de 2024 y 2025. La evidencia de la carga completa de todos los datos, la sobrecarga de memoria, los logs de los pipelines de ingesta de datos, todos han sido adjuntados como imágenes. La tabla de cobertura de estos datos se muestra: 

Año 	Mes	Tipo de Servicio	Estado	Filas
2024	1	yellow	loaded	2964624
2024	1	green	loaded	56551
2024	2	yellow	loaded	3007526
2024	2	green	loaded	53577
2024	3	yellow	loaded	3582628
2024	3	green	loaded	57457
2024	4	yellow	loaded	3514289
2024	4	green	loaded	56471
2024	5	yellow	loaded	4591845
2024	5	green	loaded	55399
2024	6	yellow	loaded	3539193
2024	6	green	loaded	54748
2024	7	yellow	loaded	-
2024	7	green	loaded	-
2024	8	yellow	loaded	-
2024	8	green	loaded	-
2024	9	yellow	loaded	-
2024	9	green	loaded	-
2024	10	yellow	loaded	3833771
2024	10	green	loaded	56147
2024	11	yellow	loaded	3646369
2024	11	green	loaded	52222
2024	12	yellow	loaded	3668371
2024	12	green	loaded	53994
2025	1	yellow	loaded	3475226
2025	1	green	loaded	48326
2025	2	yellow	loaded	3577543
2025	2	green	loaded	46621
2025	3	yellow	loaded	4145257
2025	3	green	loaded	51539
2025	4	yellow	loaded	3970553
2025	4	green	loaded	52132
2025	5	yellow	loaded	4591845
2025	5	green	loaded	55399
2025	6	yellow	loaded	4322960
2025	6	green	loaded	49390
2025	7	yellow	loaded	3898963
2025	7	green	loaded	48205
2025	8	yellow	loaded	3574091
2025	8	green	loaded	46306
2025	9	yellow	loaded	4251015
2025	9	green	loaded	48893
2025	10	yellow	loaded	4428699
2025	10	green	loaded	49416
2025	11	yellow	loaded	4181444
2025	11	green	loaded	46912


# 3. Como levantar el stack (docker compose)
El proyecto utiliza Docker y Docker Compose para que pueda ser reproducible, donde se levanta mage, postgres, pgadmin y además el network de tipo bridge para que se puedan comunicar entre si con el nombre del servicio. 

El stack incluye:
PostgreSQL 13: Data warehouse.
pgAdmin 4: UI de gestión de la base de datos.
Mage AI: Orquestador de datos.

Por esto se necesita tener Docker Desktop descargado y corriendo. 
Al copiar el proyecto, desde la raiz del proyecto correr: 

docker compose up -d --build

Para levantar todos los servicios, y permitiendo el acceso por medio de localhost, con los puertos indicados a los diferentes servicios: 
Mage AI: http://localhost:6789
user: admin@admin.com
password: admin

pgAdmin: http://localhost:8085 
credenciales definidas en docker-compose.yml.

Postgres: Accesible en localhost:5432.

Dentro del pgadmin se registra el servidor para poder utilizarlo. Dento de mage se realizo la configuración de dbt en la carpeta dbt del proyecto mage: 

cd scheduler
cd dbt
dbt init -s taxi_trips_transformations 

Al recibir un Happy Modeling! estás listo. Aquí se ha generado toda la configuración en archivos como profiles.yml dentro de dbt o la configuración física con las carpetas.

# 4. Mage Pipelines
El proyecto gira alrededor de estos pipelines. El principal para la ingesta de datos es el pipeline padre ingest_bronze, este llama a taxi_trips_ingest y zones_ingest para completar la ingesta a bronze.

## ingest_bronze
- genera las combinaciones de fecha y tipo de servicio para hacer llamadas a los pipelines de taxi_trips_ingest y zones_ingest para descargar todos los datos necesarios.
- garantiza que sean realizados uno por uno, con un tiempo de gracia (time.sleep(3)) entre cada segmento.
- también llama a los pieplines de dbt

## taxi_trips_ingest
- es llamado por ingest_bronze por cada segmento de datos.
- se encarga de descargar el parquet, añadir metadatos, gestión mínima de columnas y carga a postgres.
- maneja idempotencia al correr un delete por cada segmento según sus metadatos antes de subirlos al schema bronze.trips.
- chunking por cada 100,000 filas.

## zones_ingest
- es llamado por ingest_bronze para descargar el csv de zonas para enriquecer.
- decarga y carga simple al schema bronze.zones.

Ahora con la ingesta acabada vienen los pipelines relacionados al uso de dbt:

## dbt_silver
- contiene los bloques dbt y tests de silver

## dbt_gold
- contiene los bloques dbt y tests de gold
- modela el star schema, pero se cuelga por la memoria al hacer el fact table.
- contiene las pruebas para hacer quality checks. 


# 5. Triggers
Realmente el proyecto funciona con un solo trigger, pues este llama a ingest_bronze, hace la ingesta y después ejecuta a dbt_after_ingest que se encarga de ejecutar el dbt_silver, dbt_gold y los tests y quality checks de ambos.

##ingest_monthly
- trigger que ejecuta todo el proyecto al ejecutar el pipeline padre ingest_bronze que ejecuta todo a su tiempo.

# 6. Gestión de Secretos
Las instrucciones del proyecto son muy claras en especificar que no se deben hard-codear de ninguna manera las variables de ambientes, sean claves, puertos, etc... en un archivo .env. Por está razón, se ha utilizado Mage Secrets para poder gestionar los secretos dentro del proyecto. De igual manera, dentro del io_config.yml las variables se obtienen de secrets así: 

POSTGRES_DBNAME:  "{{ mage_secret_var('POSTGRES_DBNAME') }}"

En las evidencias se pueden ver los secretos en mage secrets. 

Diccionario de Variables de Conexión
- POSTGRES_USER: Usuario administrativo de la base de datos.
- POSTGRES_PASSWORD: Contraseña de acceso.
- POSTGRES_DB: Nombre de la base de datos destino.
- POSTGRES_HOST: Nombre del servicio en la red de Docker.
- POSTGRES_PORT: Puerto expuesto para la comunicación interna.

En los pipelines se accede con mage_secret_var.

# 7. Particionamiento
El código en dbt_gold produce tablas particionadas por diferentes técnicas en el schema analytics. En las imágenes podemos evidenciar esto. 
Sin embargo, por problemas de memoria, no se logro ejecutar el fact table.

# 8. Materializaciones
Se producen views relacionadas con la limpieza de las columnas (stg_zones, stg_taxi_trips, int_taxi_trips_zones_joined). Además se producen las tablas particionadas de dim_payment_type, dim_service_type, dim_zone y fct_trips (no ejecutada por problemas de memoria). 

Evidencia en las imágenes.

# 9. Troubleshooting 
Problemas comúnes: 

## pipeline se suspende por apagado 
La ingesta toma bastante tiempo, pero funciona sin ningún problema. En mac deja corriendo y en tu terminal corre caffeinate -i. Puedes irte a hacer lo que sea y volver cuando ya este listo.

## docker colapsa por falta de memoria 
En caso de que el docker colapse, no te preocupes, la ingesta es idempotente, y el dbt corre con facilidad. En caso de que se cuelgue el docker, entra al gestador de actividades y extermina cualquier actividad relacionada con docker. Vuelve a abrir docker desktop y vuelve a prender la imagen.

# mage no lee los secrets 
No utilices env_var, es mejor utilizar mage_get_secrets.



    




