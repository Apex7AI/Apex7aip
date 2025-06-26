# Use a public python image as a base
FROM python:3.11-slim

# Install git because the application needs it
RUN apt-get update && apt-get install -y git

# Set the working directory in the container
WORKDIR /a0

# Add the working directory to PYTHONPATH to resolve imports
ENV PYTHONPATH=/a0

# Copy the requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Expose the internal port that the application runs on
EXPOSE 80

# The command to run the application
CMD ["python", "run_ui.py"]
