CREATE DATABASE auth_db;
CREATE DATABASE job_db;
CREATE DATABASE user_db;

-- Grant all permissions to our app user
GRANT ALL PRIVILEGES ON DATABASE auth_db TO hiresignal;
GRANT ALL PRIVILEGES ON DATABASE job_db  TO hiresignal;
GRANT ALL PRIVILEGES ON DATABASE user_db TO hiresignal;