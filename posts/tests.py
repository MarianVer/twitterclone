from django.test import TestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from .models import Tweet

class TweetTest(TestCase):
    def test_create_tweet(self):
        tweet = Tweet.objects.create(text="Test tweet")
        self.assertEqual(tweet.text, "Test tweet")

    def test_image_upload(self):
        fake_image = SimpleUploadedFile("test.jpg", b"file_content", content_type="image/jpeg")
        tweet = Tweet.objects.create(text="Test", image=fake_image)
        self.assertTrue(tweet.image)
