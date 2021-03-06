# This is a basic workflow to help you get started with Actions

name: CI

# Controls when the action will run.
on:
  # Triggers the workflow on push or pull request events but only for the main branch
  push:
    branches: [ main ]

  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:
env:
    RESOURCE_GROUP_NAME: rgserverlesscmsazure
    STORAGE_ACCOUNT_NAME: sacmsazuredemo
    OAUTH_FUNCTION_APP_NAME: cmsazuredemofunc
    ORIGIN: serverlesscms.danielbass.dev
# A workflow run is made up of one or more jobs that can run sequentially or in parallel
jobs:
  # This workflow contains a single job called "build"
  build:
    # The type of runner that the job will run on
    runs-on: ubuntu-latest

    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
      # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
      - uses: actions/checkout@v2
      - name: Setup Node.js environment
        uses: actions/setup-node@v2.1.4

      - name: Cache npm
        uses: actions/cache@v2
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      - name: Azure Login
        uses: Azure/login@v1
        with:
          # Paste output of `az ad sp create-for-rbac` as value of secret variable: AZURE_CREDENTIALS
          creds: ${{ secrets.AZURE_CREDENTIALS }}
          # Set this value to true to enable Azure PowerShell Login in addition to Az CLI login
          enable-AzPSSession: false
          # Name of the environment. Supported values are azurecloud, azurestack, azureusgovernment, azurechinacloud, azuregermancloud. Default being azurecloud
          environment: azurecloud
          # Set this value to true to enable support for accessing tenants without subscriptions
          #allow-no-subscriptions: # optional

      - name: Create Resource Group
        uses: Azure/cli@1.0.4
        with:
          # Specify the script here
          inlineScript: az group create -n ${{ env.RESOURCE_GROUP_NAME }} --location UKSouth

      - name: Deploy Azure Resource Manager (ARM) Template
        id: deploy
        uses: Azure/arm-deploy@v1
        with:
          # Provide the scope of the deployment. Valid values are: 'resourcegroup', 'managementgroup', 'subscription'
          scope: resourcegroup
          # Provide the Id of the subscription which should be used, only required for resource Group or Subscription deployments.
          subscriptionId: ${{ secrets.SUBSCRIPTION_ID }}
          # Provide the name of a resource group, only required for resource Group deployments.
          resourceGroupName: ${{ env.RESOURCE_GROUP_NAME }}
          # Specify the path or URL to the Azure Resource Manager template.
          template: environment/azuredeploy.json
          # Incremental (only add resources to resource group) or Complete (remove extra resources from resource group) or Validate (only validates the template).
          deploymentMode: Incremental
          # Supply deployment parameter values.
          parameters: storageAccount_name=${{env.STORAGE_ACCOUNT_NAME}} oauthFunctionAppName=${{ env.OAUTH_FUNCTION_APP_NAME }} oauthClientId=${{ secrets.OAUTH_CLIENT_ID }} oauthClientSecret=${{ secrets.OAUTH_CLIENT_SECRET }} origin=${{ env.ORIGIN }} redirectUrl=https://${{ env.OAUTH_FUNCTION_APP_NAME }}.azurewebsites.net/callback
      
      - name: Install packages for OAuth Function
        run: |
          cd ./oauthfunc
          npm ci

      - name: Deploy OAuth Function Code
        uses: Azure/functions-action@v1.3.1
        with:
          app-name: ${{env.OAUTH_FUNCTION_APP_NAME}}
          package: ./oauthfunc
          scm-do-build-during-deployment: true
          enable-oryx-build: true
