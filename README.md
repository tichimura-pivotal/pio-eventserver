# Heroku buildpack for PredictionIO

[PredictionIO](http://predictionio.incubator.apache.org) is an open source machine learning framework. 

Two apps are composed to make a basic PredictionIO service:

1. **Engine**: a specialized machine learning app which provides training of a model and then queries against that model; generated from a [template](https://predictionio.incubator.apache.org/gallery/template-gallery/) or [custom code](https://predictionio.incubator.apache.org/customize/).
2. **Eventserver**: a simple HTTP API app for capturing events to process from other systems; shareable between multiple engines.

This buildpack will deploy both of these apps: Engine when `engine.json` is present and otherwise Eventserver.

The limited resources of a single dyno restrict use of typically large, statistically significant datasets. Only **Performance-L** dynos with 14GB RAM (currently $16/day) provide reasonable utility in this configuration.

## Docs 📚

✏️ Throughout these docs, code terms that start with `$` represent a value (shell variable) that should be replaced with a customized value, e.g `$eventserver_name`, `$engine_name`, `$postgres_addon_id`…

* [Eventserver](#eventserver)
  1. [Create the eventserver](#create-the-eventserver)
  1. [Deploy the eventserver](#deploy-the-eventserver)
* [Engine](#engine)
  1. [Create an engine](#create-an-engine)
  1. [Create a Heroku app for the engine](#create-a-heroku-app-for-the-engine)
  1. [Create a PredictionIO app in the eventserver](#create-a-predictionio-app-in-the-eventserver)
  1. [Configure the Heroku app to use the eventserver](#configure-the-heroku-app-to-use-the-eventserver)
  1. [Update `engine.json`](#update-engine-json)
  1. [Import data](#import-data)
  1. [Deploy to Heroku](#deploy-to-heroku)
* [Training](#training)
  * [Automatic training](#automatic-training)
  * [Manual training](#manual-training)
* [Evaluation](#evaluation)
  1. [Changes required for evaluation](#changes-required-for-evaluation)
  1. [Perform evaluation](#perform-evaluation)
  1. [Re-deploy best parameters](#re-deploy-best-parameters)
* [Configuration](#configuration)
  * [Environment variables](#environment-variables)
* [Running commands](#running-commands)


## Eventserver

### Create the eventserver

```bash
git clone https://github.com/heroku/predictionio-buildpack.git pio-eventserver
cd pio-eventserver

heroku create $eventserver_name
heroku addons:create heroku-postgresql:hobby-dev
heroku buildpacks:add -i 1 https://github.com/heroku/predictionio-buildpack.git
heroku buildpacks:add -i 2 heroku/scala
```

* Note the Postgres add-on identifier, e.g. `postgresql-aerodynamic-00000`; use it below in place of `$postgres_addon_id`
* You may want to specify `heroku-postgresql:standard-0` instead, because the free `hobby-dev` database is limited to 10,000 records.

### Deploy the eventserver

We delay deployment until the database is ready.

```bash
heroku pg:wait && git push heroku master
```


## Engine

Select an engine from the [gallery](https://predictionio.incubator.apache.org/gallery/template-gallery/). Download a `.tar.gz` from Github and open/expand it on your local computer.

🚨 Avoid engines that persist their model to the filesystem, which is incompatible with the [emphermeral filesystem](https://devcenter.heroku.com/articles/dynos#ephemeral-filesystem) of Heroku dynos. These engines must be modified to use Amazon S3 or the database for persistence. 

### Create an engine

`cd` into the engine's directory, and ensure it is a git repo:

```bash
git init
```

### Create a Heroku app for the engine

```bash
heroku create $engine_name
heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-jvm-common.git
heroku buildpacks:add -i 2 https://github.com/heroku/predictionio-buildpack.git
```

### Create a PredictionIO app in the eventserver

```bash
heroku run 'pio app new $pio_app_name' -a $eventserver_name
```

* This returns an access key for the app; use it below in place of `$pio_app_access_key`.

### Configure the Heroku app to use the eventserver

Replace the Postgres ID & eventserver config values with those from above:

```bash
heroku addons:attach $postgres_addon_id
heroku config:set \
  PIO_EVENTSERVER_HOSTNAME=$eventserver_name.herokuapp.com \
  PIO_EVENTSERVER_PORT=80 \
  PIO_EVENTSERVER_ACCESS_KEY=$pio_app_access_key \
  PIO_EVENTSERVER_APP_NAME=$pio_app_name
```

* See [environment variables](#environment-variables) for config details.

### Update `engine.json`

Modify this file to make sure the `appName` parameter matches the app record [created in the eventserver](#generate-an-app-record-on-the-eventserver).

```json
  "datasource": {
    "params" : {
      "appName": "$pio_app_name"
    }
  }
```

* If the `appName` param is missing, you may need to [upgrade the template](https://predictionio.incubator.apache.org/resources/upgrade/).

### Import data

🚨 Mandatory: data is required for training to succeed and then to serve predictive queries.

This step will vary based on the engine. Typically, a command formatted like the following, should be run locally:

```bash
python ./data/import_eventserver.py --url https://$eventserver_name.herokuapp.com --access_key $pio_app_access_key
```

* check the engine's `data/` directory for exact naming & format.
* `pip install predictionio` may be required for the import script to run

### Deploy to Heroku

```bash
git add .
git commit -m "Initial PIO engine"
git push heroku master
```

## Training

### Automatic training

`pio train` will automatically run during [release-phase of the Heroku app](https://devcenter.heroku.com/articles/release-phase).

### Manual training

```bash
heroku run train

# You may need to revive the app from "crashed" state.
heroku restart
```

## Scale up

Once deployed, scale up the processes to avoid memory issues:

```bash
heroku ps:scale web=1:Performance-M release=0:Performance-L train=0:Performance-L
```

## Evaluation

PredictionIO provides an [Evaluation mode for engines](https://predictionio.incubator.apache.org/evaluation/), which uses cross-validation to help select optimum engine parameters.

⚠️ Only engines that contain `src/main/scala/Evaluation.scala` support Evaluation mode.

### Changes required for evaluation

To run evaluation on Heroku, ensure `src/main/scala/Evaluation.scala` references the engine's name through the environment. Check the source file to verify that `appName` is set to `sys.env("PIO_EVENTSERVER_APP_NAME")`. For example:

```scala
DataSourceParams(appName = sys.env("PIO_EVENTSERVER_APP_NAME"), evalK = Some(5))
```

♻️ If that change was made, then commit, deploy, & re-train before proceeding.

### Perform evaluation

Next, start a console & change to the engine's directory:

```bash
heroku run bash --size Performance-L
$ cd pio-engine/
```

Then, start the process, specifying the evaluation & engine params classes from the `Evaluation.scala` source file. For example:

```bash
$ pio eval \
    org.template.classification.AccuracyEvaluation \
    org.template.classification.EngineParamsList  \
    -- --driver-class-path /app/lib/postgresql_jdbc.jar
```

### Re-deploy best parameters

Once `pio eval` completes, still in the Heroku console, copy the contents of `best.json`:

```bash
$ cat best.json
```

♻️ Paste into your local `engine.json`, commit, & deploy.


## Configuration

### Environment variables

Engine deployments honor the following config vars:

* `PIO_OPTS`
  * options passed as `pio $opts`
  * see: [`pio` command reference](https://predictionio.incubator.apache.org/cli/)
  * example:

    ```bash
    heroku config:set PIO_OPTS='--variant best.json'
    ```
* `PIO_SPARK_OPTS` & `PIO_TRAIN_SPARK_OPTS`
  * **deploy** & **training** options passed through to `spark-submit $opts`
  * see: [`spark-submit` reference](http://spark.apache.org/docs/1.6.1/submitting-applications.html)
  * example:

    ```bash
    heroku config:set \
      PIO_SPARK_OPTS='--total-executor-cores 2 --executor-memory 1g' \
      PIO_TRAIN_SPARK_OPTS='--total-executor-cores 8 --executor-memory 4g'
    ```
* `PIO_EVENTSERVER_HOSTNAME`
  * `$eventserver_name.herokuapp.com`
* `PIO_EVENTSERVER_PORT`
  * always `80` for Heroku apps
* `PIO_EVENTSERVER_APP_NAME` & `PIO_EVENTSERVER_ACCESS_KEY`
  * generated by running `pio app new $pio_app_name` on the eventserver
* `PIO_TRAIN_ON_RELEASE`
  * set `false` to disable automatic training
  * subsequent deploys will crash a deployed engine until it's retrained; use [manual training](#manual-training)

## Running commands

`pio` commands that require DB access will need to have the driver specified as an argument (bug with PIO 0.9.5 + Spark 1.6.1):

```bash
pio $command -- --driver-class-path /app/lib/postgresql_jdbc.jar
```

#### To run directly with Heroku CLI

```bash
heroku run "cd pio-engine && pio $command -- --driver-class-path /app/lib/postgresql_jdbc.jar"
```

#### Useful commands

Check engine status:

```bash
heroku run "cd pio-engine && pio status -- --driver-class-path /app/lib/postgresql_jdbc.jar"
```

