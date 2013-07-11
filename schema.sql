CREATE TABLE IF NOT EXISTS account (
	id INT NOT NULL AUTO_INCREMENT,
	email VARCHAR(255) NOT NULL,
	password_hash VARCHAR(100),
	password_salt VARCHAR(64),
	first_name VARCHAR(64),
	last_name VARCHAR(64),
	stripe_customer_id VARCHAR(64) NOT NULL,
	PRIMARY KEY (id),
	UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS license (
	id INT NOT NULL AUTO_INCREMENT,
	account_id INT,
	license_key VARCHAR(64) NOT NULL,
	is_valid BOOLEAN NOT NULL,
	type VARCHAR(64) NOT NULL,
	server_id VARCHAR(64),
	used_trial BOOLEAN NOT NULL,
	unpaid_expiration INT,
	last_ping INT,
	PRIMARY KEY (id),
	FOREIGN KEY (account_id) REFERENCES account(id),
	UNIQUE (license_key)
);

CREATE TABLE IF NOT EXISTS license_permission (
	id INT NOT NULL AUTO_INCREMENT,
	license_id INT NOT NULL,
	name VARCHAR(64) NOT NULL,
	value VARCHAR(64) NOT NULL,
	PRIMARY KEY (id),
	FOREIGN KEY (license_id) REFERENCES license(id),
	UNIQUE (license_id, name)
);

CREATE TABLE IF NOT EXISTS license_metadata (
	id INT NOT NULL AUTO_INCREMENT,
	license_id INT NOT NULL,
	name VARCHAR(64) NOT NULL,
	value VARCHAR(64) NOT NULL,
	PRIMARY KEY (id),
	FOREIGN KEY (license_id) REFERENCES license(id),
	UNIQUE (license_id, name)
);
