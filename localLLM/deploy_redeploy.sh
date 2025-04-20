# docker compose pull	Télécharge la dernière version de chaque image définie dans le docker-compose.yml
# docker compose up -d	Lance les services en mode détaché
# --force-recreate	Recrée tous les conteneurs, même si rien n’a changé
# --always-recreate-deps	Recrée aussi les dépendances indirectes (volumes, réseaux liés, etc.)

# Require Hugging Face Token
echo 'export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' >> ~/.bashrc && source ~/.bashrc

docker compose up -d

# Force pull now included in docker compose file
# docker compose pull && docker compose up -d --force-recreate
