import random
from db import create_db, save_data_session

create_db()

#generate 10 random integers between -100 and 100
random_data = [random.randint(-100, 100) for _ in range(10)]

#write to database
save_data_session(random_data)

print("Saved random data to database:", random_data)
