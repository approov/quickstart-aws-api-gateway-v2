FROM public.ecr.aws/lambda/nodejs:14

# Assumes your function is named "app.js", and there is a package.json file in the app directory.
COPY package.json  /var/task/

# Install NPM dependencies for function
RUN npm install

COPY app.js logger.js config.js /var/task/

ENV AWS_SDK_LOAD_CONFIG=true

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "app.handler" ]  
