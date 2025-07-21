import asyncio
import asyncpg
from fastapi import FastAPI, Body
from kafka import KafkaProducer
import json, os

db_host = os.environ["POSTGRES_HOST"]
db_name = os.environ["POSTGRES_DB"]
db_user = os.environ["POSTGRES_USER"]
db_password = os.environ["POSTGRES_PASSWORD"]
db_port = int(os.environ["POSTGRES_PORT"])

DATABASE_URL = f'postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'

app = FastAPI(title="Banking Transactions Producer")

producer = KafkaProducer(
    bootstrap_servers=[os.environ["KAFKA_BOOTSTRAP_SERVERS"]],
    value_serializer=lambda x: json.dumps(x).encode('utf-8')
)

async def init_db():
    """Initialize database with transactions table"""
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS transactions (
                id SERIAL PRIMARY KEY,
                account_id varchar(50) NOT NULL,
                amount decimal(15,2) NOT NULL,
                currency varchar(3) DEFAULT 'USD',
                transaction_type varchar(20) NOT NULL,
                description text,
                created_at timestamp DEFAULT CURRENT_TIMESTAMP,
                status varchar(20) DEFAULT 'pending'
                CONSTRAINT check_status CHECK(status IN('pending', 'completed', 'failed'))
            )
        ''')
        await conn.close()
        print("Banking transactions table initialized")
    except Exception as e:
        print(f"Database initialization error: {e}")

async def get_transactions():
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        result = await conn.fetch("SELECT * FROM transactions ORDER BY created_at DESC")
        await conn.close()
        return [dict(record) for record in result]
    except Exception as e:
        return {"error": str(e)}

async def get_transaction(id):
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        result = await conn.fetchrow("SELECT * FROM transactions WHERE id = $1", int(id))
        await conn.close()
        return dict(result) if result else {"error": "Transaction not found"}
    except Exception as e:
        return {"error": str(e)}

async def create_transaction(transaction_data: dict):
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        result = await conn.fetchrow('''
            INSERT INTO transactions (account_id, amount, currency, transaction_type, description)
            VALUES ($1, $2, $3, $4, $5) RETURNING *
        ''', 
        transaction_data['account_id'],
        float(transaction_data['amount']),
        transaction_data.get('currency', 'USD'),
        transaction_data['transaction_type'],
        transaction_data.get('description', '')
        )
        await conn.close()
        
        res = dict(result)
        producer.send('banking.transactions', {'action': 'create', 'data': res})
        producer.flush()
        return res
    except Exception as e:
        return {"error": str(e)}

async def update_transaction_status(id: int, status: str):
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        result = await conn.fetchrow('''
            UPDATE transactions SET status = $1 WHERE id = $2 RETURNING *
        ''', status, id)
        await conn.close()
        
        if result:
            res = dict(result)
            producer.send('banking.transactions', {'action': 'update', 'data': res})
            producer.flush()
            return res
        return {"error": "Transaction not found"}
    except Exception as e:
        return {"error": str(e)}

@app.on_event("startup")
async def startup_event():
    await init_db()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "banking-producer"}

@app.get("/transactions")
async def get_transactions_route():
    return await get_transactions()

@app.get("/transaction/{id}")
async def get_transaction_route(id: int):
    return await get_transaction(id)

@app.post("/transaction")
async def create_transaction_route(transaction: dict = Body(...)):
    return await create_transaction(transaction)

@app.put("/transaction/{id}/status")
async def update_transaction_status_route(id: int, status: str = Body(..., embed=True)):
    return await update_transaction_status(id, status)

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
