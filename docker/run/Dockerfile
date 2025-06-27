    # Use uma imagem base oficial e leve do Python
    FROM python:3.11-slim
    
    # Instale o git, que é uma dependência para o requirements.txt
    RUN apt-get update && apt-get install -y git
    
    # Defina o diretório de trabalho dentro do contêiner
    WORKDIR /a0
    
    # Copie o arquivo de requisitos primeiro para aproveitar o cache do Docker
    COPY requirements.txt .
    
    # Instale as dependências do Python
    RUN pip install --no-cache-dir -r requirements.txt
    
    # Copie todo o código da aplicação para o diretório de trabalho
    COPY . .
    
    # Exponha a porta em que a aplicação vai rodar
    EXPOSE 80
    
    # Defina o comando para iniciar a aplicação
    CMD ["python", "run_ui.py"]