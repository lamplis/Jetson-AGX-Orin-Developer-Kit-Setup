# docker compose pull	Télécharge la dernière version de chaque image définie dans le docker-compose.yml
# docker compose up -d	Lance les services en mode détaché
# --force-recreate	Recrée tous les conteneurs, même si rien n’a changé
# --always-recreate-deps	Recrée aussi les dépendances indirectes (volumes, réseaux liés, etc.)


docker compose pull && docker compose up -d --force-recreate
