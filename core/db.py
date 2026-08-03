import os
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import declarative_base, sessionmaker

Base = declarative_base()

class RequestLog(Base):
    __tablename__ = 'requests'
    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    ip_address = Column(String, nullable=False)
    api_key = Column(String)
    endpoint = Column(String, nullable=False)
    method = Column(String, nullable=False)
    status_code = Column(Integer, nullable=False)
    response_time_ms = Column(Integer)
    user_agent = Column(String)
    decision = Column(String) # 'allowed', 'throttled', 'blocked'

class RateLimitEvent(Base):
    __tablename__ = 'rate_limit_events'
    id = Column(Integer, primary_key=True, autoincrement=True)
    request_id = Column(Integer, ForeignKey('requests.id'))
    algorithm = Column(String)
    window_start = Column(DateTime)
    window_end = Column(DateTime)
    request_count = Column(Integer)
    threshold = Column(Integer)
    action = Column(String)

class FlaggedEntity(Base):
    __tablename__ = 'flagged_entities'
    id = Column(Integer, primary_key=True, autoincrement=True)
    entity_type = Column(String) # 'ip' or 'api_key'
    entity_value = Column(String, nullable=False)
    abuse_score = Column(Integer)
    risk_tier = Column(String)
    reason = Column(String)
    first_seen = Column(DateTime, default=datetime.utcnow)
    last_seen = Column(DateTime, default=datetime.utcnow)

class RulesConfig(Base):
    __tablename__ = 'rules_config'
    id = Column(Integer, primary_key=True, autoincrement=True)
    rule_name = Column(String)
    threshold_value = Column(Integer)
    window_seconds = Column(Integer)
    is_active = Column(Boolean, default=True)

# Set up SQLite database
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'api_logs.db')
engine = create_engine(f'sqlite:///{DB_PATH}', echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    Base.metadata.create_all(bind=engine)
    
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
