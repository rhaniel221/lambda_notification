import psycopg2
import boto3
import os
from datetime import datetime

# Função para publicar a mensagem no SNS
def enviar_notificacao_sns(mensagem):
    sns_client = boto3.client('sns', region_name='us-east-1')
    topic_arn = os.environ['SNS_TOPIC_ARN']
    
    try:
        response = sns_client.publish(
            TopicArn=topic_arn,
            Message=mensagem,
            Subject='Alerta de Erros no Sistema'
        )
        print(f"Notificação enviada com sucesso. Message ID: {response['MessageId']}")
    except Exception as e:
        print(f"Falha ao enviar a notificação SNS: {str(e)}")


# Função para conectar ao PostgreSQL e calcular o percentual de erros dos últimos 10 minutos
def executar_select_percentual_erros(event, context):
    percentual_erros = 0  # Inicializando variável
    
    try:
        # Conectar ao banco de dados
        conn = psycopg2.connect(
            host=os.environ['DB_HOST'],
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD'],
            port="5432"
        )
        
        cursor = conn.cursor()

        # Query para calcular o percentual de erros (status = 500) nos últimos 10 minutos
        query = """
        SELECT 
            COUNT(*) AS total_executions,
            COUNT(CASE WHEN status = 500 THEN 1 END) AS total_errors
        FROM 
            dashboardmonitoramento
        WHERE 
            data_inicio >= (CURRENT_TIMESTAMP - INTERVAL '10 minutes');
        """

        # Executar o SELECT
        cursor.execute(query)

        # Buscar e imprimir o resultado
        resultado = cursor.fetchone()
        total_executions = resultado[0]
        total_errors = resultado[1]

        # Evitar divisão por zero
        if total_executions > 0:
            percentual_erros = round((total_errors * 100.0) / total_executions, 1)
        else:
            percentual_erros = 0

        print(f"Percentual de Erros (últimos 10 minutos): {percentual_erros}%")

        # Verificar se o percentual de erros é maior que 10%
        if percentual_erros > 10:
            print("Percentual de erros maior que 10%. Enviando notificação para o SNS...")
            enviar_notificacao_sns(f"O percentual de erros nos últimos 10 minutos é {percentual_erros}%, o que excede o limite de 10%.")
        else:
            print("Percentual de erros dentro do limite aceitável.")

        cursor.close()
        conn.close()
    
    except Exception as e:
        print(f"Erro ao executar o SELECT: {e}")

    return {
        "statusCode": 200,
        "body": f"Percentual de Erros (últimos 10 minutos): {percentual_erros}%"
    }