from django.shortcuts import render, redirect
from .models import Tweet

def tweet_list(request):
    tweets = Tweet.objects.all()
    return render(request, 'posts/list.html', {'tweets': tweets})
