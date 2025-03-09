#!/bin/bash

# スーパーユーザー権限でファイルを削除
echo a | sudo -S rm objects/*
echo a | sudo -S rm results/*
