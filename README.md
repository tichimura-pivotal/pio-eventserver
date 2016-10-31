# PredictionIO classification app

Predictive classification powered by [PredictionIO](https://predictionio.incubator.apache.org), machine learning on [Heroku](http://www.heroku.com).

This is a demo application of PredictionIO preset for simplified deployment. **Custom PredictionIO engines** may be deployed as well, see [CUSTOM documentation](CUSTOM.md).

Once deployed, this engine demonstrates prediction of the best fitting **service plan** for a **mobile phone user** based on their **voice, data, and text usage**. The model is trained with a small, example data set.

## How To 📚

✏️ Throughout this document, code terms that start with `$` represent a value (shell variable) that should be replaced with a customized value, e.g `$eventserver_name`, `$engine_name`, `$postgres_addon_id`…

### Deploy to Heroku

Please follow steps in order.

1. [Requirements](#1-requirements)
1. [Eventserver](#2-eventserver)
  1. [Create the eventserver](#create-the-eventserver)
  1. [Deploy the eventserver](#deploy-the-eventserver)
1. [Classification engine](#3-classification-engine)
  1. [Create the engine](#create-the-engine)
  1. [Connect the engine with the eventserver](#connect-the-engine-with-the-eventserver)
  1. [Import data](#import-data)
  1. [Deploy the engine](#deploy-the-engine)

### Usage

Once deployed, how to work with the engine.

* [Scale-up](#scale-up)
* 🎯 [Query for predictions](#query-for-predictions)
* [Diagnostics](#diagnostics)


# Deploy to Heroku 🚀

## 1. Requirements

* [Heroku account](https://signup.heroku.com)
* [Heroku CLI](https://toolbelt.heroku.com), command-line tools
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## 2. Eventserver

### Create the eventserver

```bash
git clone \
  https://github.com/heroku/predictionio-buildpack.git \
  pio-eventserver

cd pio-eventserver

heroku create $eventserver_name
heroku addons:create heroku-postgresql:hobby-dev
heroku buildpacks:add -i 1 https://github.com/heroku/predictionio-buildpack.git
heroku buildpacks:add -i 2 heroku/scala
```

### Deploy the eventserver

We delay deployment until the database is ready.

```bash
heroku pg:wait && git push heroku master
```


## 3. Classification Engine

We'll be using a [classification engine for Heroku](https://github.com/heroku/predictionio-engine-classification) which implements [Apache Spark MLlib's Naive Bayes algorithm](https://spark.apache.org/docs/1.6.2/mllib-naive-bayes.html) to predict a label from a set of attributes. See the [Classification Quickstart](http://predictionio.incubator.apache.org/templates/classification/quickstart/) for more about this engine.

### Create the engine

```bash
git clone \
  https://github.com/heroku/predictionio-engine-classification.git \
  pio-engine-classi

cd pio-engine-classi

heroku create $engine_name
heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-jvm-common.git
heroku buildpacks:add -i 2 https://github.com/heroku/predictionio-buildpack.git
```

### Connect the engine with the eventserver

First, collect a few configuration values.

#### Get the eventserver's database add-on ID

```bash
heroku addons:info heroku-postgresql --app $eventserver_name
#
# Use the returned Postgres add-on ID
# to attach it to the engine.
# Example: `postgresql-aerodynamic-00000`
#
heroku addons:attach $postgres_addon_id --app $engine_name
```

#### Get an access key for this engine's data

```bash
heroku run 'pio app new classi' --app $eventserver_name
#
# Use the returned access key for `$pio_app_access_key`
#
heroku config:set \
  PIO_EVENTSERVER_HOSTNAME=$eventserver_name.herokuapp.com \
  PIO_EVENTSERVER_PORT=80 \
  PIO_EVENTSERVER_ACCESS_KEY=$pio_app_access_key \
  PIO_EVENTSERVER_APP_NAME=classi
```

### Import data

🚨 Mandatory: data is required for training. The model cannot answer predictive queries until trained with data.

When deployed, the engine will automatically train a model to predict the best fitting **service plan** for a **mobile phone user** based on their **voice, data, and text usage**. We'll use the engine's [example data and import script](https://github.com/heroku/predictionio-engine-classification/tree/master/data) for initial training.

* `pip install predictionio` may be required before the import script will run; see [how-to install pip](https://pip.pypa.io/en/stable/installing/)

```bash
python ./data/import_eventserver.py \
  --url https://$eventserver_name.herokuapp.com \
  --access_key $pio_app_access_key
```

### Deploy the engine

```bash
git push heroku master

# Follow the logs to see training 
# and then start-up of the engine.
#
heroku logs -t --app $engine_name
```


# Usage ⌨️

## Scale up

Once deployed, scale up the processes and config Spark to avoid memory issues. These are paid, [professional dyno types](https://devcenter.heroku.com/articles/dyno-types#available-dyno-types):

```bash
heroku ps:scale \
  web=1:Standard-2X \
  release=0:Performance-L \
  train=0:Performance-L \
  --app $engine_name
```

## Query for predictions

Once deployment completes, the engine is ready to predict the best fitting **service plan** for a **mobile phone user** based on their **voice, data, and text usage**.

Submit queries containing these three user attributes to get predictions using [Apache Spark MLlib's Naive Bayes algorithm](https://spark.apache.org/docs/1.6.2/mllib-naive-bayes.html):

```bash
# Fits more voice, `1`
curl -X "POST" "https://$engine_name.herokuapp.com/queries.json" \
     -H "Content-Type: application/json; charset=utf-8" \
     -d "{\"voice_usage\":480,\"data_usage\":0,\"text_usage\":121}"

# Fits more data, `2`
curl -X "POST" "https://$engine_name.herokuapp.com/queries.json" \
     -H "Content-Type: application/json; charset=utf-8" \
     -d "{\"voice_usage\":25,\"data_usage\":1000,\"text_usage\":80}"

#Fits more texts, `3`
curl -X "POST" "https://$engine_name.herokuapp.com/queries.json" \
     -H "Content-Type: application/json; charset=utf-8" \
     -d "{\"voice_usage\":5,\"data_usage\":80,\"text_usage\":1000}"
```

This model is simplified for demonstration. For a real-world model more aspects of a user account and their correlations might be taken into consideration, including: account type (individual, business, or family), frequency of roaming, international usage, device type (smart phone or feature phone), age of device, etc.

See [usage details for this classification engine](http://predictionio.incubator.apache.org/templates/classification/quickstart/#6.-use-the-engine) in the PredictionIO docs.


## Diagnostics

If you hit any snags with the engine serving queries, check the logs:

```bash
heroku logs -t --app $engine_name
```

If errors are occuring, sometimes a restart will help:

```bash
heroku restart --app $engine_name
```


# Going Deeper 🔬

This is a demo application of PredictionIO, already customized for the smoothest experience possible.

**Custom PredictionIO engines** may be deployed with this buildpack too. See [CUSTOM documentation](CUSTOM.md).

More details including [training](CUSTOM.md#training), [evaluation](CUSTOM.md#evaluation), & [configuration](CUSTOM.md#configuration) are explained there to.

