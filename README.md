# BADSEC NOClist Client

This is a Ruby client script written to perform the AdHoc homework specified here: https://homework.adhoc.team/noclist/

## How to run the script

1. First, ensure that you have the BADSEC server running locally by following [AdHoc's instructions](https://homework.adhoc.team/noclist/#running-the-server).

1. Ensure you have your local Ruby environment set up to use `ruby-2.6.5` and the bundler gem.

1. Pull down the project and navigate to `jla_noclist_client`

1. In your command console, run:
	```unix
	bundle install
	ruby lib/client.rb
	```

The user list output will appear in the console if the script runs successfully. Otherwise, there will be error logs, and the script will exit after unsuccessfully retrying either of the two requests 2 times.

## How to run tests

In your command console, run:

```unix
rspec
```

or if that isn't working,

```unix
bundle exec rspec
```