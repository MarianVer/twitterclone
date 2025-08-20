# Базовий образ
FROM python:3.12-slim

# Робоча директорія
WORKDIR /app

# Копіювання залежностей
COPY requirements.txt .

# Встановлення залежностей
RUN pip install --no-cache-dir -r requirements.txt

# Копіювання коду проекту
COPY . .

# Команда запуску
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

EXPOSE 8001
