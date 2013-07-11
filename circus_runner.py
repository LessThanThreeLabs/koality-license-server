#!/usr/bin/env python

import os
import pwd

try:
	from circus.arbiter import Arbiter
	from circus.watcher import Watcher
except ImportError:
	print "Couldn't import circus, attempting to download and retry."
	try:
		import subprocess
		subprocess.call(['pip', 'install', 'circus==0.7.1'])
		from circus.arbiter import Arbiter
		from circus.watcher import Watcher
	except:
		print "Couldn't install circus. Try running 'sudo pip install circus' manually."
		raise


class LicenseServerCircusRunner(object):
	root_directory = os.path.abspath(os.path.dirname(__file__))
	log_directory = os.path.join(root_directory, 'log')

	def __init__(self):
		try:
			user = pwd.getpwnam(os.environ.get('SUDO_USER', os.environ.get('USER')))
		except:
			raise Exception("Cannot retrieve user information")

		if not os.access(self.log_directory, os.F_OK):
			os.makedirs(self.log_directory)

		self.watchers = [
			# LICENSE SERVER
			Watcher(
				name='license-server',
				cmd='/usr/bin/node',
				args=['--harmony', os.path.join(self.root_directory, 'libs', 'index.js'), '--mode', 'production'],
				working_dir=self.root_directory,
				stdout_stream={'filename': os.path.join(self.log_directory, 'licenseServer_stdout.log')},
				stderr_stream={'filename': os.path.join(self.log_directory, 'licenseServer_stderr.log')},
				uid=user[2],
				gid=user[3],
				copy_env=True,
				copy_path=True,
				priority=1
			),
		]

	def run(self):
		arbiter = Arbiter(self.watchers, 'tcp://127.0.0.1:5555', 'tcp://127.0.0.1:5556', debug=True)
		try:
			arbiter.start()
		finally:
			arbiter.stop()


def main():
	LicenseServerCircusRunner().run()


if __name__ == '__main__':
	main()
