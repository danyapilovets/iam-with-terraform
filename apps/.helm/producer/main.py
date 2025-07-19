import json
import db_connect_events
import uvicorn
from fastapi import FastAPI
from kafka import KafkaProducer
import asyncio

producer = KafkaProducer(bootstrap_servers=['kafka:9092'], value_serializer=lambda x: json.dumps(x).encode('utf-8'))


app = FastAPI()

def events_create():
    sql_createEvents = '''CREATE TABLE IF NOT EXISTS Events (
        id SERIAL PRIMARY KEY,
        type varchar(255),
        team_1 varchar(255),
        team_2 varchar(255),
        event_date varchar(255),
        score varchar(50),
        state varchar(50)
        CONSTRAINT check_state
        CHECK(state IN('created', 'active', 'finished'))); '''
    db_connect_events.cursor.execute(sql_createEvents)
    print("Table Events Created")


events_create()

async def get_events():
    query = "SELECT * FROM events"
    try:
        db_connect_events.cursor.execute(query)
        return db_connect_events.cursor.fetchall()
    except:
        return "Cannot get all events"


async def get_event(id):
    query = 'SELECT * FROM events WHERE id = {}'.format(id)
    try:
        db_connect_events.cursor.execute(query)
        return db_connect_events.cursor.fetchall()
    except:
        return "Cannot fetch user with id"


async def delete_event(id):
    query = "DELETE FROM events WHERE id = {}".format(id)
    try:
        db_connect_events.cursor.execute(query)
        return "Deleted event with id {}".format(id)
    except:
        return "Cannot delete user with id"

async def update_event(col, val):
    try:

        res = dict(zip(col.split(), val.split()))
        producer.send('events.taxonomy', dict(update=res))
        producer.flush()
        return res
    except:
        return "Cannot delete bet with id"


async def create_event(col, val):
    try:
        res = dict(zip(col.split(), val.split()))
        producer.send('events.taxonomy', dict(create=res))
        producer.flush()
        return res
    except:
         return "Something went wrong when creating new event"

@app.get("/events")
async def get_events_route():
    return await get_events()

@app.get("/event")
async def get_event_route(id):
    return await get_event(id)

@app.delete("/event")
async def delete_event_route(id):
    return await delete_event(id)

@app.put("/event")
async def update_event_route(col, val):
    return await update_event(col, val)

@app.post("/event")
async def create_event_route(col, val):
    return await create_event(col, val)


if __name__ == '__main__':
    uvicorn.run(app, host="0.0.0.0", port=8001)
    loop = asyncio.get_event_loop()
    loop.run_until_complete(app)
